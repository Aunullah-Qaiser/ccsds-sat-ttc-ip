# Architecting a Universal CCSDS Spacecraft TT&C and Ground EGSE Transceiver IP Core in SystemVerilog (`CCSDS-SAT-TTC-IP v2.15`)

> **Companion files in `docs/`:**
> - Typeset PDF Monograph: `docs/ccsds_ttc_ip_engineering_book.pdf`
> - LaTeX Source: `docs/ccsds_ttc_ip_engineering_book.tex`
> - Master Target Specification: `docs/ccsds_ttc_rtl_spec_and_live_plan.md`

## Executive Summary: What We Are Building, What Is Built (Stages 0–8), and What Is Left (Stages 9–12)

| Subsystem / Layer | Current Status | What Is Built & Verified Today (`v2.15`, Stages 0–8) | What Is Left for TRL-9 Flight Silicon (Stages 9–12) |
| :--- | :--- | :--- | :--- |
| **1. Multi-Protocol Framing (`TM`, `TC`, `AOS`, `Proximity-1`, `USLP`)** | **100% Built** | All 5 protocols, Cycle-0 closed-form `FHP`, 8B CUC `OBT` Secondary Header, $GF(2^4)$ `FHEC`, `0x55` fill stripping, CRC-16/32 | ESA/NASA SLE ground software bridge & multi-VC dynamic QoS shaping |
| **2. Closed-Loop ARQ (`FARM-1`, `FOP-1`, `PLCW`)** | **100% Built** | 3x TMR `FARM-1`, Two-Phase SDLS commit/rollback, Type-BC unlock exemption, Ground `FOP-1` Go-Back-$N$ replay | Unbounded formal property proof via SymbiYosys / JasperGold |
| **3. Classic FEC (`BCH(63,56)`, `RS(255,223)`, `Conv/Viterbi`)** | **90% Built** | Uplink `BCH(63,56)` SEC-DED + CLTU encoder; Downlink Dual-Basis `RS(255,223)` encoder ($I=1..8$, implicit $Q$); 64-state Viterbi | Full Berlekamp-Massey + Chien/Forney $t=16$ symbol error correction in Ground EGSE `RS` decoder |
| **4. Next-Gen FEC (Short-LDPC, AR4JA LDPC, RSC Turbo)** | **75% Built** | Working $(128,64)$ Min-Sum Short-LDPC iterative decoder & AR4JA/Turbo streaming encoder cores | Full $(512,256)$ & $(8192,4096)$ CCSDS protograph ROM tables + 1-stage Min-Sum check-node pipeline (`>310 MHz` `clk_sys`) |
| **5. Inline Space Security (`SDLS` CCSDS 355.0-B-2)** | **80% Built** | Hsiao $(39,32)$ SECDED SA RAM, anti-replay window, 1-byte lookahead MAC tag stripper, Two-Phase `FARM-1` interlock | Replace lightweight cipher mixer with full 14-round AES-256-GCM ($GF(2^{128})$ Karatsuba `GHASH`) & HMAC-SHA-256 |
| **6. Baseband RF PHY & T2B/T4B PN Ranging** | **85% Built** | Costas loop, Q32 $240/221$ & $880/749$ turnaround NCO, 6-channel T2B/T4B PN correlator ($L=1,009,470$) | 16-tap polyphase RRC matched filter & fractional Gardner symbol timing recovery loop |
| **7. SoC Bus, Scatter-Gather DMA & Flight Software BSP** | **60% Built** | 3x TMR `AXI4-Lite` CSR, 48-bit CUC `OBT` timer, saturating EDAC counters, `AXI4-Stream` packet ports | Autonomous `AXI4`/`AHB` Scatter-Gather DMA master + RTEMS / FreeRTOS / NASA cFS C drivers |
| **8. Rad-Hard `techmap` & RF FlatSat Qualification** | **70% Built** | Kintex UltraScale OOC synthesis & True-$F_{\max}$ (`248.8–312.5 MHz`), `<3.9%` LUT area, GitHub Actions CI | Vendor `techmap` wrappers (RTG4, PolarFire RT, XQRKU060 SEM) & live RFSoC coaxial HIL testing |
