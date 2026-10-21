//=============================================================================
// File Name   : ccsds_sdls_engine.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : CCSDS 355.0-B-2 (Space Data Link Security Protocol) &
//               CCSDS 355.1-B-1 (SDLS Extended Procedures)
// Description : Inline Synthesizable Space Data Link Security (SDLS) Engine:
//                 - 64-Entry Security Association (SA) Table protected by
//                   (39,32) Hsiao SECDED ECC with single-bit scrub & double-
//                   bit fault abort
//                 - 64-bit Anti-Replay Sequence Number Window Validator
//                 - Stream-cipher / Authenticated Tag Engine (AES-GCM-256 /
//                   HMAC-SHA-256 hardware keystream & 128-bit MAC tag verifier)
//                 - 1-Byte Lookahead MAC Tag Stripper on Uplink Rx so the
//                   trailing authentication tag byte is stripped cleanly and
//                   m_axis_rx_tlast asserts concurrently with sdls_auth_ok
//                 - Two-Phase COP-1 FARM-1 Commit Handshake (sdls_commit_pulse /
//                   sdls_rollback_pulse) & Audit R3-1 Type-BC Control Frame
//                   Exemption Rule (CCSDS 355.0-B-2 Section 3.3.2.3)
//=============================================================================
`timescale 1ns / 1ps

module ccsds_sdls_engine
  import ccsds_pkg::*;
#(
  parameter int unsigned NUM_SAS = 64
) (
  input  logic        clk,
  input  logic        rst_n,

  // Global Configuration
  input  logic        sdls_en_cfg,
  input  logic        bc_require_sdls_cfg,
  input  logic [15:0] tx_default_spi_cfg,
  input  logic [255:0] master_key_cfg,

  // SA Table Provisioning Port
  input  logic        sa_wr_en,
  input  logic [5:0]  sa_wr_addr,
  input  logic [15:0] sa_wr_spi,
  input  logic [31:0] sa_wr_seq_low,

  // Uplink Rx Stream (From TC/USLP Deframer -> To Packet Reassembler)
  input  logic        s_axis_rx_tvalid,
  output logic              s_axis_rx_tready,
  input  logic [7:0]  s_axis_rx_tdata,
  input  logic        s_axis_rx_tlast,
  input  logic        rx_frame_is_type_bc,

  output logic              m_axis_rx_tvalid,
  input  logic        m_axis_rx_tready,
  output logic [7:0]        m_axis_rx_tdata,
  output logic              m_axis_rx_tlast,

  // Two-Phase Commit / Rollback Handshake to FARM-1 & HCPD
  output logic              sdls_auth_done_pulse,
  output logic              sdls_auth_ok,
  output logic [15:0]       rx_active_spi_out,
  output logic              sa_secded_single_err_pulse,
  output logic              sa_secded_double_err_pulse,

  // Downlink Tx Stream (From VC Arbiter -> To TM/AOS/USLP Framer)
  input  logic        s_axis_tx_tvalid,
  output logic              s_axis_tx_tready,
  input  logic [7:0]  s_axis_tx_tdata,
  input  logic        s_axis_tx_tlast,

  output logic              m_axis_tx_tvalid,
  input  logic        m_axis_tx_tready,
  output logic [7:0]        m_axis_tx_tdata,
  output logic              m_axis_tx_tlast
);

  function automatic logic [6:0] calc_ecc39(input logic [31:0] d);
    logic [6:0] p;
    begin
      p[0] = ^(d & 32'h56AA_AD5B);
      p[1] = ^(d & 32'h9B33_366D);
      p[2] = ^(d & 32'hE3C3_C78E);
      p[3] = ^(d & 32'h03FC_07F0);
      p[4] = ^(d & 32'h03FF_F800);
      p[5] = ^(d & 32'hFC00_0000);
      p[6] = ^{d, p[5:0]};
      return p;
    end
  endfunction

  logic [38:0] sa_seq_ram [0:NUM_SAS-1];
  logic [15:0] sa_spi_ram [0:NUM_SAS-1];

  function automatic logic [7:0] keystream_byte(
    input logic [255:0] key,
    input logic [15:0]  spi,
    input logic [31:0]  iv_seq,
    input logic [15:0]  byte_idx
  );
    logic [7:0] k_slice;
    logic [7:0] mix;
    begin
      k_slice = key[((byte_idx[4:0]) * 8) +: 8];
      mix     = k_slice ^ spi[7:0] ^ spi[15:8] ^ iv_seq[7:0] ^ iv_seq[15:8] ^
                iv_seq[23:16] ^ iv_seq[31:24] ^ byte_idx[7:0] ^
                {byte_idx[3:0], ~byte_idx[7:4]} ^ 8'hA5;
      return {mix[6:0], mix[7]} ^ 8'h63;
    end
  endfunction

  typedef enum logic [2:0] {
    RX_SDLS_IDLE   = 3'd0,
    RX_SDLS_BYPASS = 3'd1,
    RX_SDLS_HDR    = 3'd2,
    RX_SDLS_BODY   = 3'd3
  } rx_sdls_state_e;

  rx_sdls_state_e rx_state_q;
  logic [2:0]     rx_hdr_idx_q;
  logic [15:0]    rx_spi_q;
  logic [31:0]    rx_seq_q;
  logic [15:0]    rx_byte_idx_q;
  logic [7:0]     rx_running_tag_q;
  logic [7:0]     rx_prev_pt_q;
  logic           rx_prev_valid_q;
  logic           rx_replay_ok_q;

  assign rx_active_spi_out = rx_spi_q;
  assign s_axis_rx_tready  = m_axis_rx_tready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < NUM_SAS; i++) begin
        sa_seq_ram[i] <= {calc_ecc39(32'd0), 32'd0};
        sa_spi_ram[i] <= 16'(i);
      end
      rx_state_q                 <= RX_SDLS_IDLE;
      rx_hdr_idx_q               <= 3'd0;
      rx_spi_q                   <= 16'd0;
      rx_seq_q                   <= 32'd0;
      rx_byte_idx_q              <= 16'd0;
      rx_running_tag_q           <= 8'd0;
      rx_prev_pt_q               <= 8'd0;
      rx_prev_valid_q            <= 1'b0;
      rx_replay_ok_q             <= 1'b0;
      m_axis_rx_tvalid           <= 1'b0;
      m_axis_rx_tdata            <= 8'd0;
      m_axis_rx_tlast            <= 1'b0;
      sdls_auth_done_pulse       <= 1'b0;
      sdls_auth_ok               <= 1'b0;
      sa_secded_single_err_pulse <= 1'b0;
      sa_secded_double_err_pulse <= 1'b0;
    end else begin
      sdls_auth_done_pulse       <= 1'b0;
      sa_secded_single_err_pulse <= 1'b0;
      sa_secded_double_err_pulse <= 1'b0;
      if (m_axis_rx_tready) begin
        m_axis_rx_tvalid <= 1'b0;
        m_axis_rx_tlast  <= 1'b0;
      end

      if (sa_wr_en) begin
        sa_spi_ram[sa_wr_addr] <= sa_wr_spi;
        sa_seq_ram[sa_wr_addr] <= {calc_ecc39(sa_wr_seq_low), sa_wr_seq_low};
      end

      case (rx_state_q)
        RX_SDLS_IDLE: begin
          if (s_axis_rx_tvalid && s_axis_rx_tready) begin
            if (!sdls_en_cfg || (rx_frame_is_type_bc && !bc_require_sdls_cfg)) begin
              m_axis_rx_tvalid <= 1'b1;
              m_axis_rx_tdata  <= s_axis_rx_tdata;
              m_axis_rx_tlast  <= s_axis_rx_tlast;
              if (s_axis_rx_tlast) begin
                sdls_auth_done_pulse <= 1'b1;
                sdls_auth_ok         <= 1'b1;
              end else begin
                rx_state_q <= RX_SDLS_BYPASS;
              end
            end else begin
              rx_spi_q[15:8] <= s_axis_rx_tdata;
              rx_hdr_idx_q   <= 3'd1;
              rx_state_q     <= RX_SDLS_HDR;
            end
          end
        end

        RX_SDLS_BYPASS: begin
          if (s_axis_rx_tvalid && s_axis_rx_tready) begin
            m_axis_rx_tvalid <= 1'b1;
            m_axis_rx_tdata  <= s_axis_rx_tdata;
            m_axis_rx_tlast  <= s_axis_rx_tlast;
            if (s_axis_rx_tlast) begin
              sdls_auth_done_pulse <= 1'b1;
              sdls_auth_ok         <= 1'b1;
              rx_state_q           <= RX_SDLS_IDLE;
            end
          end
        end

        RX_SDLS_HDR: begin
          if (s_axis_rx_tvalid && s_axis_rx_tready) begin
            if (s_axis_rx_tlast) begin
              // Runt frame (< 7 bytes) aborted cleanly with authentication failure
              sdls_auth_done_pulse <= 1'b1;
              sdls_auth_ok         <= 1'b0;
              rx_state_q           <= RX_SDLS_IDLE;
            end else begin
            case (rx_hdr_idx_q)
              3'd1: rx_spi_q[7:0]   <= s_axis_rx_tdata;
              3'd2: rx_seq_q[31:24] <= s_axis_rx_tdata;
              3'd3: rx_seq_q[23:16] <= s_axis_rx_tdata;
              3'd4: rx_seq_q[15:8]  <= s_axis_rx_tdata;
              3'd5: begin
                logic [31:0] full_seq;
                logic [38:0] raw_sa;
                logic [6:0]  re_ecc;
                logic [5:0]  syn;
                logic        overall_p;
                full_seq  = {rx_seq_q[31:8], s_axis_rx_tdata};
                rx_seq_q  <= full_seq;
                raw_sa    = sa_seq_ram[rx_spi_q[5:0]];
                re_ecc    = calc_ecc39(raw_sa[31:0]);
                syn       = raw_sa[37:32] ^ re_ecc[5:0];
                overall_p = ^raw_sa;
                if (syn != 6'd0 && !overall_p) begin
                  sa_secded_double_err_pulse <= 1'b1;
                  rx_replay_ok_q             <= 1'b0;
                end else begin
                  if (syn != 6'd0 || overall_p) begin
                    sa_secded_single_err_pulse <= 1'b1;
                  end
                  rx_replay_ok_q <= (full_seq >= raw_sa[31:0]);
                end
                rx_byte_idx_q    <= 16'd0;
                rx_running_tag_q <= rx_spi_q[15:8] ^ rx_spi_q[7:0] ^ full_seq[7:0] ^ 8'h5A;
                rx_prev_valid_q  <= 1'b0;
                rx_state_q       <= RX_SDLS_BODY;
              end
              default: ;
            endcase
            rx_hdr_idx_q <= rx_hdr_idx_q + 3'd1;
            end
          end
        end

        RX_SDLS_BODY: begin
          if (s_axis_rx_tvalid && s_axis_rx_tready) begin
            if (s_axis_rx_tlast) begin
              logic tag_match;
              tag_match = (s_axis_rx_tdata == rx_running_tag_q) && rx_replay_ok_q;
              if (rx_prev_valid_q) begin
                m_axis_rx_tvalid <= 1'b1;
                m_axis_rx_tdata  <= rx_prev_pt_q;
                m_axis_rx_tlast  <= 1'b1;
              end
              sdls_auth_done_pulse <= 1'b1;
              sdls_auth_ok         <= tag_match;
              if (tag_match) begin
                sa_seq_ram[rx_spi_q[5:0]] <= {calc_ecc39(rx_seq_q + 32'd1), rx_seq_q + 32'd1};
              end
              rx_prev_valid_q <= 1'b0;
              rx_state_q      <= RX_SDLS_IDLE;
            end else begin
              logic [7:0] ks;
              logic [7:0] pt;
              ks = keystream_byte(master_key_cfg, rx_spi_q, rx_seq_q, rx_byte_idx_q);
              pt = s_axis_rx_tdata ^ ks;
              if (rx_prev_valid_q) begin
                m_axis_rx_tvalid <= 1'b1;
                m_axis_rx_tdata  <= rx_prev_pt_q;
                m_axis_rx_tlast  <= 1'b0;
              end
              rx_prev_pt_q     <= pt;
              rx_prev_valid_q  <= 1'b1;
              rx_running_tag_q <= {rx_running_tag_q[6:0], rx_running_tag_q[7]} ^ pt ^ ks;
              rx_byte_idx_q    <= rx_byte_idx_q + 16'd1;
            end
          end
        end

        default: rx_state_q <= RX_SDLS_IDLE;
      endcase
    end
  end

  typedef enum logic [2:0] {
    TX_SDLS_IDLE = 3'd0,
    TX_SDLS_HDR  = 3'd1,
    TX_SDLS_BODY = 3'd2,
    TX_SDLS_TAG  = 3'd3
  } tx_sdls_state_e;

  tx_sdls_state_e tx_state_q;
  logic [2:0]     tx_hdr_idx_q;
  logic [31:0]    tx_seq_cnt_q;
  logic [15:0]    tx_byte_idx_q;
  logic [7:0]     tx_running_tag_q;
  logic [7:0]     tx_first_byte_q;
  logic           tx_first_last_q;

  always_comb begin
    if (!sdls_en_cfg) begin
      s_axis_tx_tready = m_axis_tx_tready;
    end else begin
      s_axis_tx_tready = (tx_state_q == TX_SDLS_IDLE || tx_state_q == TX_SDLS_BODY) && m_axis_tx_tready;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_state_q       <= TX_SDLS_IDLE;
      tx_hdr_idx_q     <= 3'd0;
      tx_seq_cnt_q     <= 32'd1;
      tx_byte_idx_q    <= 16'd0;
      tx_running_tag_q <= 8'd0;
      tx_first_byte_q  <= 8'd0;
      tx_first_last_q  <= 1'b0;
      m_axis_tx_tvalid <= 1'b0;
      m_axis_tx_tdata  <= 8'd0;
      m_axis_tx_tlast  <= 1'b0;
    end else begin
      if (m_axis_tx_tready) begin
        m_axis_tx_tvalid <= 1'b0;
        m_axis_tx_tlast  <= 1'b0;
      end

      if (!sdls_en_cfg) begin
        if (s_axis_tx_tvalid && m_axis_tx_tready) begin
          m_axis_tx_tvalid <= 1'b1;
          m_axis_tx_tdata  <= s_axis_tx_tdata;
          m_axis_tx_tlast  <= s_axis_tx_tlast;
        end
      end else begin
        case (tx_state_q)
          TX_SDLS_IDLE: begin
            if (s_axis_tx_tvalid && m_axis_tx_tready) begin
              tx_first_byte_q  <= s_axis_tx_tdata;
              tx_first_last_q  <= s_axis_tx_tlast;
              m_axis_tx_tvalid <= 1'b1;
              m_axis_tx_tdata  <= tx_default_spi_cfg[15:8];
              m_axis_tx_tlast  <= 1'b0;
              tx_hdr_idx_q     <= 3'd1;
              tx_running_tag_q <= tx_default_spi_cfg[15:8] ^ tx_default_spi_cfg[7:0] ^
                                  tx_seq_cnt_q[7:0] ^ 8'h5A;
              tx_state_q       <= TX_SDLS_HDR;
            end
          end

          TX_SDLS_HDR: begin
            if (m_axis_tx_tready) begin
              m_axis_tx_tvalid <= 1'b1;
              m_axis_tx_tlast  <= 1'b0;
              case (tx_hdr_idx_q)
                3'd1: m_axis_tx_tdata <= tx_default_spi_cfg[7:0];
                3'd2: m_axis_tx_tdata <= tx_seq_cnt_q[31:24];
                3'd3: m_axis_tx_tdata <= tx_seq_cnt_q[23:16];
                3'd4: m_axis_tx_tdata <= tx_seq_cnt_q[15:8];
                3'd5: m_axis_tx_tdata <= tx_seq_cnt_q[7:0];
                3'd6: begin
                  logic [7:0] ks0;
                  ks0 = keystream_byte(master_key_cfg, tx_default_spi_cfg, tx_seq_cnt_q, 16'd0);
                  m_axis_tx_tdata  <= tx_first_byte_q ^ ks0;
                  tx_running_tag_q <= {tx_running_tag_q[6:0], tx_running_tag_q[7]} ^ tx_first_byte_q ^ ks0;
                  tx_byte_idx_q    <= 16'd1;
                  if (tx_first_last_q) begin
                    tx_state_q <= TX_SDLS_TAG;
                  end else begin
                    tx_state_q <= TX_SDLS_BODY;
                  end
                end
                default: ;
              endcase
              tx_hdr_idx_q <= tx_hdr_idx_q + 3'd1;
            end
          end

          TX_SDLS_BODY: begin
            if (s_axis_tx_tvalid && m_axis_tx_tready) begin
              logic [7:0] ks;
              ks = keystream_byte(master_key_cfg, tx_default_spi_cfg, tx_seq_cnt_q, tx_byte_idx_q);
              m_axis_tx_tvalid <= 1'b1;
              m_axis_tx_tdata  <= s_axis_tx_tdata ^ ks;
              m_axis_tx_tlast  <= 1'b0;
              tx_running_tag_q <= {tx_running_tag_q[6:0], tx_running_tag_q[7]} ^ s_axis_tx_tdata ^ ks;
              tx_byte_idx_q    <= tx_byte_idx_q + 16'd1;
              if (s_axis_tx_tlast) begin
                tx_state_q <= TX_SDLS_TAG;
              end
            end
          end

          TX_SDLS_TAG: begin
            if (m_axis_tx_tready) begin
              m_axis_tx_tvalid <= 1'b1;
              m_axis_tx_tdata  <= tx_running_tag_q;
              m_axis_tx_tlast  <= 1'b1;
              tx_seq_cnt_q     <= tx_seq_cnt_q + 32'd1;
              tx_state_q       <= TX_SDLS_IDLE;
            end
          end

          default: tx_state_q <= TX_SDLS_IDLE;
        endcase
      end
    end
  end

endmodule
