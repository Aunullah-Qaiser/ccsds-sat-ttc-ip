#!/usr/bin/env python3
"""
===============================================================================
File Name   : run_external_ref_check.py
Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
Description : Stage 9 External Reference Interoperability Generator & Verifier
              using:
                - University of Stuttgart IRS `spacepackets` library
                  (https://github.com/us-irs/spacepackets-py, `pip install spacepackets`)
                - PyCA `cryptography` NIST FIPS-197 AES-128 library
                  (`from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes`)
              Modes:
                1. --generate : Generates external golden hex stimulus files in
                                `sim_waves/` for Vivado xsim:
                                  - ext_ref_ul_cltu.hex           (42B CLTU with TC + SP)
                                  - ext_ref_ul_uslp.hex           (31B USLP Ext Frame + SP)
                                  - ext_ref_dl_pkt.hex            (16B Telemetry Space Packet)
                                  - ext_ref_sdls_rx_frame.hex     (21B AES-128-CTR SDLS Frame)
                                  - ext_ref_rs_corrupted_cw.hex   (60B RS(255,223) CW w/ 2 byte errors)
                                  - ext_ref_ldpc128_noisy_cbs.hex (32B = Two (128,64) LDPC CBs w/ 2 bit errors each)
                2. --verify   : Reads the raw hex output files dumped by Vivado
                                xsim and validates them against `spacepackets`,
                                `cryptography` AES-128, Dual-Basis RS(255,223),
                                and CCSDS 231.1-O-1 Table 2-1/2-4 (128,64) LDPC.
===============================================================================
"""

from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path
from typing import Tuple, List
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
WAVES_DIR = REPO_ROOT / "sim_waves"

try:
    from spacepackets.ccsds import SpacePacketHeader, PacketType, SequenceFlags
    HAVE_SPACEPACKETS = True
except ImportError:
    HAVE_SPACEPACKETS = False

NIST_FIPS197_KEY16 = bytes.fromhex("2B7E151628AED2A6ABF7158809CF4F3C")

# Official CCSDS 231.1-O-1 Table 2-1 (n=128, k=64) Generator Matrix W_64x64 Base Rows
LDPC128_W_BASE = [
    [0x0E69, 0x166B, 0xEF4C, 0x0BC2],  # Row 1  (block row 0)
    [0x7766, 0x137E, 0xBB24, 0x8418],  # Row 17 (block row 1)
    [0xC480, 0xFEB9, 0xCD53, 0xA713],  # Row 33 (block row 2)
    [0x4EAA, 0x22FA, 0x465E, 0xEA11],  # Row 49 (block row 3)
]


def ror16(val: int, s: int) -> int:
    s %= 16
    return ((val >> s) | ((val << (16 - s)) & 0xFFFF)) & 0xFFFF


def encode_ccsds_ldpc128_block(info8: bytes) -> bytes:
    """Encodes an 8-byte (64-bit) block into a 16-byte (128-bit) codeblock per CCSDS 231.1-O-1 Table 2-1."""
    assert len(info8) == 8
    info_int = int.from_bytes(info8, "big")
    par64 = 0
    for r in range(64):
        bit = (info_int >> (63 - r)) & 1
        if bit:
            br = r // 16
            sh = r % 16
            w_row = 0
            for bc in range(4):
                w_row = (w_row << 16) | ror16(LDPC128_W_BASE[br][bc], sh)
            par64 ^= w_row
    return info8 + par64.to_bytes(8, "big")


def aes128_ecb_encrypt_block(key16: bytes, block16: bytes) -> bytes:
    assert len(key16) == 16 and len(block16) == 16
    enc = Cipher(algorithms.AES(key16), modes.ECB()).encryptor()
    return enc.update(block16) + enc.finalize()


def sdls_aes128_ctr_encrypt(key16: bytes, spi: int, seq_num: int, plaintext: bytes) -> bytes:
    sec_hdr = spi.to_bytes(2, "big") + seq_num.to_bytes(4, "big")
    ct = bytearray()
    tag = ((spi >> 8) & 0xFF) ^ (spi & 0xFF) ^ (seq_num & 0xFF) ^ 0x5A
    ks_block = b""
    for idx, pt_b in enumerate(plaintext):
        if (idx & 0xF) == 0:
            blk_idx = idx >> 4
            ctr_blk = (
                bytes.fromhex("CC5D")
                + spi.to_bytes(2, "big")
                + seq_num.to_bytes(4, "big")
                + bytes.fromhex("53444C530000")
                + blk_idx.to_bytes(2, "big")
            )
            ks_block = aes128_ecb_encrypt_block(key16, ctr_blk)
        ks_b = ks_block[idx & 0xF]
        ct.append(pt_b ^ ks_b)
        tag = (((tag << 1) & 0xFE) | ((tag >> 7) & 1)) ^ pt_b ^ ks_b
    return sec_hdr + bytes(ct) + bytes([tag])


def sdls_aes128_ctr_decrypt_and_verify(key16: bytes, sdls_frame: bytes) -> Tuple[int, int, bytes]:
    assert len(sdls_frame) >= 7
    spi = int.from_bytes(sdls_frame[0:2], "big")
    seq_num = int.from_bytes(sdls_frame[2:6], "big")
    ct = sdls_frame[6:-1]
    rx_tag = sdls_frame[-1]

    pt = bytearray()
    calc_tag = ((spi >> 8) & 0xFF) ^ (spi & 0xFF) ^ (seq_num & 0xFF) ^ 0x5A
    ks_block = b""
    for idx, ct_b in enumerate(ct):
        if (idx & 0xF) == 0:
            blk_idx = idx >> 4
            ctr_blk = (
                bytes.fromhex("CC5D")
                + spi.to_bytes(2, "big")
                + seq_num.to_bytes(4, "big")
                + bytes.fromhex("53444C530000")
                + blk_idx.to_bytes(2, "big")
            )
            ks_block = aes128_ecb_encrypt_block(key16, ctr_blk)
        ks_b = ks_block[idx & 0xF]
        pt_b = ct_b ^ ks_b
        pt.append(pt_b)
        calc_tag = (((calc_tag << 1) & 0xFE) | ((calc_tag >> 7) & 1)) ^ pt_b ^ ks_b

    assert rx_tag == calc_tag, f"SDLS Tag mismatch: got 0x{rx_tag:02X}, expected 0x{calc_tag:02X}"
    return spi, seq_num, bytes(pt)


def build_ccsds_space_packet(is_tc: bool, apid: int, seq_count: int, payload: bytes) -> Tuple[bytes, str]:
    if HAVE_SPACEPACKETS:
        sp_hdr = SpacePacketHeader(
            packet_type=PacketType.TC if is_tc else PacketType.TM,
            apid=apid,
            seq_count=seq_count,
            data_len=len(payload) - 1,
            seq_flags=SequenceFlags.UNSEGMENTED,
            sec_header_flag=False,
        )
        return sp_hdr.pack() + payload, "spacepackets.ccsds.SpacePacketHeader"
    else:
        w0 = ((0 & 0x7) << 13) | ((1 if is_tc else 0) << 12) | (0 << 11) | (apid & 0x7FF)
        w1 = (0b11 << 14) | (seq_count & 0x3FFF)
        w2 = (len(payload) - 1) & 0xFFFF
        hdr6 = w0.to_bytes(2, "big") + w1.to_bytes(2, "big") + w2.to_bytes(2, "big")
        return hdr6 + payload, "CCSDS-133.0-B-2-Std-Struct (run `pip install spacepackets` for external lib)"


def unpack_and_verify_space_packet(raw_pkt: bytes, exp_is_tc: bool, exp_apid: int, exp_seq: int, exp_payload: bytes) -> dict:
    assert len(raw_pkt) == 6 + len(exp_payload), (
        f"Length mismatch: got {len(raw_pkt)} bytes, expected {6 + len(exp_payload)}"
    )
    if HAVE_SPACEPACKETS:
        hdr = SpacePacketHeader.unpack(raw_pkt[:6])
        assert hdr.apid == exp_apid, f"APID mismatch: {hdr.apid:#x} != {exp_apid:#x}"
        assert hdr.seq_count == exp_seq, f"SeqCount mismatch: {hdr.seq_count} != {exp_seq}"
        assert hdr.data_len == len(exp_payload) - 1, f"DataLen mismatch: {hdr.data_len}"
        assert (hdr.packet_type == PacketType.TC) == exp_is_tc, "PacketType mismatch"
        parser_used = "spacepackets.ccsds.SpacePacketHeader.unpack"
    else:
        w0 = int.from_bytes(raw_pkt[0:2], "big")
        w1 = int.from_bytes(raw_pkt[2:4], "big")
        w2 = int.from_bytes(raw_pkt[4:6], "big")
        apid = w0 & 0x7FF
        is_tc = ((w0 >> 12) & 1) == 1
        seq = w1 & 0x3FFF
        dlen = w2
        assert apid == exp_apid, f"APID mismatch: {apid:#x} != {exp_apid:#x}"
        assert seq == exp_seq, f"SeqCount mismatch: {seq} != {exp_seq}"
        assert dlen == len(exp_payload) - 1, f"DataLen mismatch: {dlen}"
        assert is_tc == exp_is_tc, "PacketType mismatch"
        parser_used = "CCSDS-133.0-B-2-Unpacker"

    body = raw_pkt[6:]
    assert body == exp_payload, f"Payload mismatch: {body!r} != {exp_payload!r}"
    return {
        "parser": parser_used,
        "apid_hex": f"0x{exp_apid:03X}",
        "seq_count": exp_seq,
        "payload_ascii": exp_payload.decode("ascii"),
        "raw_hex": raw_pkt.hex().upper(),
    }


def crc16_ccitt(data: bytes) -> int:
    crc = 0xFFFF
    for b in data:
        crc ^= (b << 8)
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if (crc & 0x8000) else ((crc << 1) & 0xFFFF)
    return crc


def bch6356_encode_block(info7: bytes) -> bytes:
    val = int.from_bytes(info7, "big")
    rem = 0
    for i in range(55, -1, -1):
        fb = ((rem >> 6) & 1) ^ ((val >> i) & 1)
        rem = (rem << 1) & 0x7F
        if fb:
            rem ^= 0x45
    par_inv = (~rem) & 0x7F
    cb64 = (val << 8) | (par_inv << 1) | 0
    return cb64.to_bytes(8, "big")


def tc_randomize(data: bytes) -> bytes:
    sr = 0xFF
    out = bytearray()
    for b in data:
        pn = 0
        for _ in range(8):
            pn = (pn << 1) | (sr & 1)
            fb = bin(sr & 0x5F).count("1") & 1
            sr = (sr >> 1) | (fb << 7)
        out.append(b ^ pn)
    return bytes(out)


def tm_derandomize(data: bytes) -> bytes:
    sr = 0xFF
    out = bytearray()
    for b in data:
        pn = 0
        for _ in range(8):
            pn = (pn << 1) | (sr & 1)
            fb = bin(sr & 0xA9).count("1") & 1
            sr = (sr >> 1) | (fb << 7)
        out.append(b ^ pn)
    return bytes(out)


def write_hex_file(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"{b:02X}" for b in data]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def read_hex_file(path: Path) -> bytes:
    lines = [ln.strip() for ln in path.read_text(encoding="utf-8").splitlines() if ln.strip() and not ln.strip().startswith("//")]
    return bytes(int(x, 16) for x in lines)


def generate_vectors() -> dict:
    sys.path.insert(0, str(REPO_ROOT / "egse_model"))
    import ccsds_ground_egse_model as egse

    WAVES_DIR.mkdir(parents=True, exist_ok=True)

    # Verify NIST FIPS-197 Appendix B Golden Vector first
    fips_pt = bytes.fromhex("3243F6A8885A308D313198A2E0370734")
    fips_ct = aes128_ecb_encrypt_block(NIST_FIPS197_KEY16, fips_pt)
    assert fips_ct.hex().upper() == "3925841D02DC09FBDC118597196A0B32"

    # 1. External Uplink Telecommand Space Packet (14 bytes: 6B Hdr + 8B "SAT_CMD1")
    ul_sp, src_lib = build_ccsds_space_packet(is_tc=True, apid=0x245, seq_count=19, payload=b"SAT_CMD1")
    tc_len_c = 22 - 1
    tc_hdr40 = (0 << 38) | (0 << 37) | (0 << 36) | (0 << 34) | (0x155 << 24) | (1 << 18) | (tc_len_c << 8) | 0
    tc_wo_crc = tc_hdr40.to_bytes(5, "big") + bytes([0xC0]) + ul_sp
    tc_frame = tc_wo_crc + crc16_ccitt(tc_wo_crc).to_bytes(2, "big")

    padded_tc = tc_frame + (b"\x55" * 6)
    scrambled_tc = tc_randomize(padded_tc)
    cltu = bytearray(b"\xEB\x90")
    for idx in range(0, len(scrambled_tc), 7):
        cltu.extend(bch6356_encode_block(scrambled_tc[idx:idx+7]))
    cltu.extend(b"\xC5\xC5\xC5\xC5\xC5\xC5\xC5\x79")
    write_hex_file(WAVES_DIR / "ext_ref_ul_cltu.hex", bytes(cltu))
    write_hex_file(WAVES_DIR / "ext_ref_expected_ul_pkt.hex", ul_sp)

    # 2. External Uplink USLP Extended Frame (CCSDS 732.1-B-3) wrapping a 14-byte Space Packet
    uslp_sp, _ = build_ccsds_space_packet(is_tc=True, apid=0x31A, seq_count=42, payload=b"USLP_CMD")
    uslp_tot_len = 4 + 3 + 1 + 3 + len(uslp_sp) + 4 + 2  # 31 bytes
    uslp_base32 = (0xC << 28) | (0x4255 << 12) | (0 << 11) | (2 << 5) | (0 << 1) | 0
    uslp_ext24  = ((uslp_tot_len - 1) << 8) | (0 << 7) | (0 << 6) | (0 << 4) | (1 << 3) | 1
    uslp_vcf8   = b"\x07"
    uslp_tfdf24 = ((0 << 21) | (1 << 16) | 0x0000).to_bytes(3, "big")
    uslp_ocf32  = (0x01040002).to_bytes(4, "big")
    uslp_wo_crc = uslp_base32.to_bytes(4, "big") + uslp_ext24.to_bytes(3, "big") + uslp_vcf8 + uslp_tfdf24 + uslp_sp + uslp_ocf32
    uslp_frame  = uslp_wo_crc + crc16_ccitt(uslp_wo_crc).to_bytes(2, "big")
    write_hex_file(WAVES_DIR / "ext_ref_ul_uslp.hex", uslp_frame)
    write_hex_file(WAVES_DIR / "ext_ref_expected_uslp_pkt.hex", uslp_sp)

    # 3. External Downlink Telemetry Space Packet (16 bytes: 6B Hdr + 10B "TLM_OBC_OK")
    dl_sp, _ = build_ccsds_space_packet(is_tc=False, apid=0x109, seq_count=88, payload=b"TLM_OBC_OK")
    write_hex_file(WAVES_DIR / "ext_ref_dl_pkt.hex", dl_sp)

    # 4. Step 3A: External SDLS AES-128-CTR Encrypted Telecommand Frame (21 bytes)
    sdls_sp, _ = build_ccsds_space_packet(is_tc=True, apid=0x245, seq_count=99, payload=b"AES_CMD!")
    sdls_rx_frame = sdls_aes128_ctr_encrypt(NIST_FIPS197_KEY16, spi=0x0007, seq_num=0x00000005, plaintext=sdls_sp)
    write_hex_file(WAVES_DIR / "ext_ref_sdls_rx_frame.hex", sdls_rx_frame)
    write_hex_file(WAVES_DIR / "ext_ref_expected_sdls_pkt.hex", sdls_sp)

    # 5. Step 3B: Corrupted 60-byte Dual-Basis RS(255,223) Codeword (Q=195: 28B TM Frame + 32B RS Parity)
    tm_hdr48 = (0 << 46) | (0x155 << 36) | (1 << 33) | (1 << 32) | (0 << 24) | (0 << 16) | (0 << 15) | (0 << 14) | (0 << 13) | (0b11 << 11) | 0
    tm_wo_crc = tm_hdr48.to_bytes(6, "big") + dl_sp + (0x01040001).to_bytes(4, "big")
    tm_frame = tm_wo_crc + crc16_ccitt(tm_wo_crc).to_bytes(2, "big")
    rs = egse.CCSDSReedSolomon255223()
    clean_cw = bytearray(rs.encode_single(tm_frame, q_virtual_fill=195))
    corrupted_cw = bytearray(clean_cw)
    corrupted_cw[7]  ^= 0xA5
    corrupted_cw[14] ^= 0x3C
    write_hex_file(WAVES_DIR / "ext_ref_rs_corrupted_cw.hex", bytes(corrupted_cw))

    # 6. Step 3C: Two 128-bit CCSDS 231.1-O-1 Table 2-1 (128,64) LDPC Codeblocks (32 bytes)
    #    wrapping a 16-byte Space Packet (APID=0x245, Seq=105, Body="LDPC128_OK"),
    #    with 2 corrupted bits injected into EACH 128-bit codeblock!
    ldpc_sp, _ = build_ccsds_space_packet(is_tc=True, apid=0x245, seq_count=105, payload=b"LDPC128_OK")
    assert len(ldpc_sp) == 16
    cb0 = bytearray(encode_ccsds_ldpc128_block(ldpc_sp[0:8]))
    cb1 = bytearray(encode_ccsds_ldpc128_block(ldpc_sp[8:16]))
    # Flip 2 bits in Codeblock 0 (byte 1 bit 2, byte 5 bit 6) and 2 bits in Codeblock 1 (byte 0 bit 4, byte 6 bit 1)
    cb0[1] ^= 0x04
    cb0[5] ^= 0x40
    cb1[0] ^= 0x10
    cb1[6] ^= 0x02
    write_hex_file(WAVES_DIR / "ext_ref_ldpc128_noisy_cbs.hex", bytes(cb0 + cb1))
    write_hex_file(WAVES_DIR / "ext_ref_expected_ldpc_pkt.hex", ldpc_sp)

    info = {
        "generator_library": src_lib,
        "aes_library": "cryptography.hazmat.primitives.ciphers.algorithms.AES (NIST FIPS-197 AES-128)",
        "have_spacepackets_installed": HAVE_SPACEPACKETS,
        "ul_cltu_bytes": len(cltu),
        "uslp_frame_bytes": len(uslp_frame),
        "dl_space_pkt_bytes": len(dl_sp),
        "sdls_aes128_rx_frame_bytes": len(sdls_rx_frame),
        "rs_corrupted_cw_bytes": len(corrupted_cw),
        "ldpc128_noisy_cbs_bytes": len(cb0 + cb1),
        "ldpc128_injected_errors": "CB0: 2 bit flips (byte[1]^=0x04, byte[5]^=0x40); CB1: 2 bit flips (byte[0]^=0x10, byte[6]^=0x02)",
    }
    print(json.dumps(info, indent=2))
    return info


def verify_rtl_outputs() -> dict:
    sys.path.insert(0, str(REPO_ROOT / "egse_model"))
    import ccsds_ground_egse_model as egse

    ul_pkt_out = read_hex_file(WAVES_DIR / "rtl_out_ul_pkt.hex")
    uslp_pkt_out = read_hex_file(WAVES_DIR / "rtl_out_uslp_pkt.hex")
    dl_cadu_out = read_hex_file(WAVES_DIR / "rtl_out_dl_cadu.hex")
    sdls_rx_pkt_out = read_hex_file(WAVES_DIR / "rtl_out_sdls_rx_pkt.hex")
    sdls_tx_frame_out = read_hex_file(WAVES_DIR / "rtl_out_sdls_tx_frame.hex")
    rs_corr_pkt_out = read_hex_file(WAVES_DIR / "rtl_out_rs_corrected_pkt.hex")
    ldpc_dec_pkt_out = read_hex_file(WAVES_DIR / "rtl_out_ldpc_decoded_pkt.hex")
    dl_ldpc_cw_out = read_hex_file(WAVES_DIR / "rtl_out_dl_ldpc_cw.hex")

    # 1. Verify Uplink Reassembled Space Packet from CLTU->BCH->TC->Reassembler
    res_ul = unpack_and_verify_space_packet(
        ul_pkt_out, exp_is_tc=True, exp_apid=0x245, exp_seq=19, exp_payload=b"SAT_CMD1"
    )

    # 2. Verify Uplink Reassembled Space Packet from USLP->Reassembler
    res_uslp = unpack_and_verify_space_packet(
        uslp_pkt_out, exp_is_tc=True, exp_apid=0x31A, exp_seq=42, exp_payload=b"USLP_CMD"
    )

    # 3. Verify Downlink CADU emitted by VC_Arb -> TM_Framer -> RS(255,223)_Enc
    assert dl_cadu_out[:4] == b"\x1A\xCF\xFC\x1D", f"Missing 0x1ACFFC1D ASM: {dl_cadu_out[:4].hex()}"
    descrambled = tm_derandomize(dl_cadu_out[4:])
    tm_frame = descrambled[:-32]
    rs_parity = descrambled[-32:]

    assert crc16_ccitt(tm_frame) == 0x0000, f"TM Frame CRC-16 failed: 0x{crc16_ccitt(tm_frame):04X}"
    rs = egse.CCSDSReedSolomon255223()
    q_fill = 223 - len(tm_frame)
    syndromes = rs.verify_syndrome_single(tm_frame + rs_parity, q_virtual_fill=q_fill)
    assert all(s == 0 for s in syndromes), f"Non-zero RS(255,223) syndromes: {syndromes}"

    extracted_dl_sp = tm_frame[6:22]
    res_dl = unpack_and_verify_space_packet(
        extracted_dl_sp, exp_is_tc=False, exp_apid=0x109, exp_seq=88, exp_payload=b"TLM_OBC_OK"
    )

    # 4A. Verify Uplink SDLS AES-128-CTR Decrypted Space Packet from RTL
    res_sdls_rx = unpack_and_verify_space_packet(
        sdls_rx_pkt_out, exp_is_tc=True, exp_apid=0x245, exp_seq=99, exp_payload=b"AES_CMD!"
    )

    # 4B. Decrypt Downlink SDLS AES-128-CTR Frame emitted by RTL using PyCA `cryptography`
    tx_spi, tx_seq, tx_decrypted_sp = sdls_aes128_ctr_decrypt_and_verify(NIST_FIPS197_KEY16, sdls_tx_frame_out)
    assert tx_spi == 0x0007 and tx_seq == 1
    res_sdls_tx = unpack_and_verify_space_packet(
        tx_decrypted_sp, exp_is_tc=False, exp_apid=0x109, exp_seq=88, exp_payload=b"TLM_OBC_OK"
    )

    # 5. Verify Step 3B RS(255,223) Corrected Downlink Space Packet from RTL
    res_rs_corr = unpack_and_verify_space_packet(
        rs_corr_pkt_out, exp_is_tc=False, exp_apid=0x109, exp_seq=88, exp_payload=b"TLM_OBC_OK"
    )

    # 6. Verify Step 3C CCSDS 231.1-O-1 (128,64) LDPC Decoded Space Packet & Encoder Codeblock
    res_ldpc_dec = unpack_and_verify_space_packet(
        ldpc_dec_pkt_out, exp_is_tc=True, exp_apid=0x245, exp_seq=105, exp_payload=b"LDPC128_OK"
    )
    exp_dl_ldpc_cw = encode_ccsds_ldpc128_block(ldpc_dec_pkt_out[0:8])
    assert dl_ldpc_cw_out == exp_dl_ldpc_cw, (
        f"DL LDPC(128,64) CW mismatch: {dl_ldpc_cw_out.hex()} != {exp_dl_ldpc_cw.hex()}"
    )

    summary = {
        "status": "PASS",
        "have_spacepackets_installed": HAVE_SPACEPACKETS,
        "test1_ul_cltu_to_rtl_space_packet": res_ul,
        "test2_ul_uslp_to_rtl_space_packet": res_uslp,
        "test3_rtl_dl_cadu_to_external_parser": {
            **res_dl,
            "cadu_total_bytes": len(dl_cadu_out),
            "tm_frame_crc16_residue": "0x0000",
            "rs255_223_all_32_syndromes_zero": True,
            "virtual_fill_q": q_fill,
        },
        "test4_step3a_sdls_nist_aes128_ctr": {
            "ul_decrypt_from_python_cryptography": res_sdls_rx,
            "dl_encrypt_verified_by_python_cryptography": res_sdls_tx,
            "tx_spi_hex": f"0x{tx_spi:04X}",
            "tx_seq_num": tx_seq,
        },
        "test5_step3b_rs255_223_error_correction": {
            **res_rs_corr,
            "corrupted_bytes_healed": 2,
        },
        "test6_step3c_ccsds_ldpc128_and_turbo": {
            **res_ldpc_dec,
            "noisy_codeblocks_decoded": 2,
            "injected_bit_errors_healed": 4,
            "dl_ldpc128_table2_1_cw_hex": dl_ldpc_cw_out.hex().upper(),
        },
    }
    print(json.dumps(summary, indent=2))
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--generate", action="store_true", help="Generate external hex vectors for xsim")
    parser.add_argument("--verify", action="store_true", help="Verify xsim output hex dumps")
    args = parser.parse_args()
    if args.verify:
        verify_rtl_outputs()
    else:
        generate_vectors()
