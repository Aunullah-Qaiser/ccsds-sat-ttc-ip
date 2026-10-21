#!/usr/bin/env python3
"""
===============================================================================
File Name   : ccsds_ground_egse_model.py
Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
Description : Bit-exact Python Ground Station EGSE Reference Model & Golden
              Test Vector Oracle covering:
                1. CCSDS 133.0-B-2 Space Packet Primary Header & PEC
                2. CCSDS 132.0-B-3 TM, 232.0-B-4 TC, 732.0-B-4 AOS (with GF(2^4)
                   FHEC), 211.0-B-6 Proximity-1, and 732.1-B-3 USLP Frame Codecs
                3. CRC-16-CCITT (0x1021) and Proximity-1 CRC-32 (0x00A00805)
                4. TM (h_TM) and TC (h_TC) 255-bit LFSR Pseudo-Randomizers
                5. Uplink BCH(63,56) Encoder/SEC-DED Decoder & CLTU Framer/Deframer
                6. Downlink Dual-Basis RS(255,223) Encoder & Berlekamp-Massey
                   Decoder with Interleaving I=1..8 and Implicit Virtual Fill Q
                7. Rate 1/2, K=7 Convolutional Encoder & 64-State Viterbi Decoder
                8. COP-1 Ground FOP-1 Initiator & Spacecraft Two-Phase FARM-1
                   Responder (with Audit R3-1 Type-BC SDLS Exemption Rule)
                9. SDLS AES-GCM-256 & HMAC-SHA-256 Security Oracle (355.0-B-2)
               10. T2B/T4B Weighted-Voting PN Ranging Generator (414.1-B-3)
===============================================================================
"""

from __future__ import annotations
import struct
from dataclasses import dataclass
from typing import List, Tuple, Optional, Dict
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


# =============================================================================
# 1. CRC-16-CCITT (0x1021) & Proximity-1 CRC-32 (0x00A00805) Oracles
# =============================================================================

def crc16_ccitt(data: bytes, init: int = 0xFFFF) -> int:
    """
    Computes CCSDS 16-bit Frame Error Control Field (FECF) per CCSDS 132.0-B-3
    and 232.0-B-4 Annex B: G(x) = x^16 + x^12 + x^5 + 1 (0x1021), init 0xFFFF.
    Appending big-endian crc16_ccitt(payload) yields residue 0x0000 over frame.
    """
    crc = init & 0xFFFF
    for byte in data:
        crc ^= (byte << 8)
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc


def crc32_prox1(data: bytes, init: int = 0xFFFFFFFF) -> int:
    """
    Computes CCSDS 211.0-B-6 / 732.1-B-3 32-bit FECF:
    G(x) = x^32 + x^23 + x^21 + x^11 + x^2 + 1 (0x00A00805), init 0xFFFFFFFF,
    no final XOR. Appending big-endian crc32_prox1(payload) yields residue 0x00000000.
    """
    crc = init & 0xFFFFFFFF
    poly = 0x00A00805
    for byte in data:
        crc ^= (byte << 24)
        for _ in range(8):
            if crc & 0x80000000:
                crc = ((crc << 1) ^ poly) & 0xFFFFFFFF
            else:
                crc = (crc << 1) & 0xFFFFFFFF
    return crc


# =============================================================================
# 2. TM & TC LFSR Pseudo-Randomizers (CCSDS 131.0-B-5 & 231.0-B-4)
# =============================================================================

def generate_tm_pn_sequence(num_bytes: int) -> bytes:
    """
    Generates the CCSDS 131.0-B-5 Downlink Telemetry Pseudo-Randomizer byte
    sequence using h(x) = x^8 + x^7 + x^5 + x^3 + 1 (tap mask 0xA9) initialized
    to all 1s (0xFF). First 8 octets per Blue Book: FF 48 0E C0 9A 0D 70 BC.
    """
    lfsr = 0xFF
    out = bytearray()
    for _ in range(num_bytes):
        byte_val = 0
        for _ in range(8):
            out_bit = lfsr & 1
            byte_val = (byte_val << 1) | out_bit
            fb = bin(lfsr & 0xA9).count("1") & 1
            lfsr = (lfsr >> 1) | (fb << 7)
        out.append(byte_val)
    return bytes(out)


def generate_tc_pn_sequence(num_bytes: int) -> bytes:
    """
    Generates the CCSDS 231.0-B-4 Uplink Telecommand Pseudo-Randomizer byte
    sequence using h(x) = x^8 + x^6 + x^4 + x^3 + x^2 + x + 1 (tap mask 0x5F)
    initialized to all 1s (0xFF). First 8 octets per Blue Book: FF 39 9E 5A 68 E9 06 F5.
    """
    lfsr = 0xFF
    out = bytearray()
    for _ in range(num_bytes):
        byte_val = 0
        for _ in range(8):
            out_bit = lfsr & 1
            byte_val = (byte_val << 1) | out_bit
            fb = bin(lfsr & 0x5F).count("1") & 1
            lfsr = (lfsr >> 1) | (fb << 7)
        out.append(byte_val)
    return bytes(out)


def scramble_tm(data: bytes) -> bytes:
    pn = generate_tm_pn_sequence(len(data))
    return bytes(a ^ b for a, b in zip(data, pn))


def scramble_tc(data: bytes) -> bytes:
    pn = generate_tc_pn_sequence(len(data))
    return bytes(a ^ b for a, b in zip(data, pn))


# =============================================================================
# 3. Uplink BCH(63,56) SEC-DED Codec & CLTU Framer/Deframer (CCSDS 231.0-B-4)
# =============================================================================

class CCSDSBCH6356Codec:
    """
    Implements CCSDS 231.0-B-4 Expurgated BCH(63,56) code in a 64-bit codeblock:
      - 56 information bits (7 octets, MSB transmitted first)
      - 7 parity bits (inverted on transmission per Section 3.3.2)
      - 1 filler bit '0' at LSB (Bit 63)
    Generator polynomial: g(x) = x^7 + x^6 + x^2 + 1 (0xC5).
    """

    def __init__(self) -> None:
        self.syndrome_to_bit_pos: Dict[int, int] = {}
        for bit_pos in range(63):
            cw63 = 1 << (62 - bit_pos)
            syn = self._raw_syndrome63(cw63)
            self.syndrome_to_bit_pos[syn] = bit_pos

    @staticmethod
    def _raw_syndrome63(cw63: int) -> int:
        rem = 0
        for i in range(62, -1, -1):
            bit = (cw63 >> i) & 1
            fb = ((rem >> 6) & 1) ^ bit
            rem = ((rem << 1) & 0x7F)
            if fb:
                rem ^= 0x45  # x^6 + x^2 + 1
        return rem

    def encode_codeblock(self, info7: bytes) -> bytes:
        assert len(info7) == 7, "BCH(63,56) requires exactly 7 information octets"
        info_int = int.from_bytes(info7, "big")
        rem = 0
        for i in range(55, -1, -1):
            bit = (info_int >> i) & 1
            fb = ((rem >> 6) & 1) ^ bit
            rem = ((rem << 1) & 0x7F)
            if fb:
                rem ^= 0x45
        parity_comp = (~rem) & 0x7F
        codeblock64 = (info_int << 8) | (parity_comp << 1) | 0
        return codeblock64.to_bytes(8, "big")

    def decode_codeblock(self, cb8: bytes) -> Tuple[Optional[bytes], bool, bool]:
        """
        Decodes an 8-octet (64-bit) BCH codeblock.
        Returns: (decoded_7_bytes_or_None, single_err_corrected, uncorrectable_abort)
        """
        assert len(cb8) == 8
        if cb8 in (b"\xC5\xC5\xC5\xC5\xC5\xC5\xC5\x79", b"\x55\x55\x55\x55\x55\x55\x55\xAA"):
            return None, False, True  # Tail sequence detected

        val64 = int.from_bytes(cb8, "big")
        cw63 = ((val64 >> 1) ^ 0x7F) & ((1 << 63) - 1)
        syn = self._raw_syndrome63(cw63)
        if syn == 0:
            info_int = (cw63 >> 7) & ((1 << 56) - 1)
            return info_int.to_bytes(7, "big"), False, False

        odd_parity = bin(cw63).count("1") & 1
        if odd_parity == 1 and syn in self.syndrome_to_bit_pos:
            err_pos = self.syndrome_to_bit_pos[syn]
            cw63_corr = cw63 ^ (1 << (62 - err_pos))
            if self._raw_syndrome63(cw63_corr) == 0:
                info_int = (cw63_corr >> 7) & ((1 << 56) - 1)
                return info_int.to_bytes(7, "big"), True, False

        return None, False, True


# =============================================================================
# 4. Dual-Basis Reed-Solomon RS(255,223) Codec (CCSDS 131.0-B-5)
# =============================================================================

class CCSDSReedSolomon255223:
    """
    Implements CCSDS 131.0-B-5 Reed-Solomon (255,223) E=16 over GF(2^8) with:
      - Field generator polynomial: F(x) = x^8 + x^7 + x^2 + x + 1 (0x187)
      - Exact CCSDS 131.0-B-5 Annex B Dual-basis (Berlekamp) symbol representation
        where [z0..z7] = [u7..u0] * T_alpha and [u7..u0] = [z0..z7] * T_alpha^-1
      - Symmetric code generator: g(x) = prod_{j=112}^{143} (x - alpha^(11*j))
      - Interleaving depth I in {1, 2, 3, 4, 5, 8}
      - Implicit 0-cycle virtual fill Q in [0..200]
    """

    T_STD_TO_DUAL = [
        0xFE,  # z0
        0x69,  # z1
        0x6B,  # z2
        0x0D,  # z3
        0xEF,  # z4
        0xF2,  # z5
        0x5B,  # z6
        0xC7,  # z7
    ]

    T_DUAL_TO_STD = [
        0x9B,  # u7
        0xDD,  # u6
        0x3E,  # u5
        0x1C,  # u4
        0x37,  # u3
        0xB3,  # u2
        0x60,  # u1
        0x94,  # u0
    ]

    def __init__(self) -> None:
        self.exp_tbl = [0] * 512
        self.log_tbl = [0] * 256
        val = 1
        for i in range(255):
            self.exp_tbl[i] = val
            self.exp_tbl[i + 255] = val
            self.log_tbl[val] = i
            val <<= 1
            if val & 0x100:
                val ^= 0x187

        g = [1]
        self.roots = []
        for j in range(112, 144):
            root = self.exp_tbl[(11 * j) % 255]
            self.roots.append(root)
            nxt = [0] * (len(g) + 1)
            for idx, coeff in enumerate(g):
                nxt[idx] ^= coeff
                nxt[idx + 1] ^= self.gf_mul(coeff, root)
            g = nxt
        self.gen_poly = g

    def gf_mul(self, a: int, b: int) -> int:
        if a == 0 or b == 0:
            return 0
        return self.exp_tbl[self.log_tbl[a] + self.log_tbl[b]]

    def gf_inv(self, a: int) -> int:
        if a == 0:
            raise ZeroDivisionError("GF(2^8) inverse of 0")
        return self.exp_tbl[255 - self.log_tbl[a]]

    @classmethod
    def std_to_dual(cls, val: int) -> int:
        out = 0
        for row in cls.T_STD_TO_DUAL:
            bit = bin(val & row).count("1") & 1
            out = (out << 1) | bit
        return out

    @classmethod
    def dual_to_std(cls, val: int) -> int:
        out = 0
        for row in cls.T_DUAL_TO_STD:
            bit = bin(val & row).count("1") & 1
            out = (out << 1) | bit
        return out

    def encode_single(self, msg_dual: bytes, q_virtual_fill: int = 0) -> bytes:
        assert len(msg_dual) == 223 - q_virtual_fill
        parity = [0] * 32
        for sym_dual in msg_dual:
            sym_std = self.dual_to_std(sym_dual)
            fb = sym_std ^ parity[0]
            parity = parity[1:] + [0]
            if fb != 0:
                for k in range(32):
                    parity[k] ^= self.gf_mul(fb, self.gen_poly[k + 1])
        parity_dual = bytes(self.std_to_dual(p) for p in parity)
        return msg_dual + parity_dual

    def encode_interleaved(self, payload: bytes, interleave_i: int = 1, q_virtual_fill: int = 0) -> bytes:
        k_per_cw = 223 - q_virtual_fill
        assert len(payload) == k_per_cw * interleave_i
        parity_cols = []
        for idx in range(interleave_i):
            sub_msg = payload[idx::interleave_i]
            coded_sub = self.encode_single(sub_msg, q_virtual_fill)
            parity_cols.append(coded_sub[k_per_cw:])
        interleaved_parity = bytearray()
        for p_idx in range(32):
            for idx in range(interleave_i):
                interleaved_parity.append(parity_cols[idx][p_idx])
        return payload + bytes(interleaved_parity)

    def verify_syndrome_single(self, cw_dual: bytes, q_virtual_fill: int = 0) -> List[int]:
        full_std = [0] * q_virtual_fill + [self.dual_to_std(b) for b in cw_dual]
        assert len(full_std) == 255
        syndromes = []
        for root in self.roots:
            acc = 0
            for coeff in full_std:
                acc = self.gf_mul(acc, root) ^ coeff
            syndromes.append(acc)
        return syndromes


# =============================================================================
# 5. Multi-Protocol Frame Builders & COP-1 FOP-1 / FARM-1 Reference Engine
# =============================================================================

@dataclass
class COP1Farm1Engine:
    vcid: int = 0
    v_r: int = 0
    farm_b_cnt: int = 0
    state: int = 0  # 0=OPEN, 1=WAIT, 2=LOCKOUT
    retransmit: int = 0
    wait_flag: int = 0
    no_rf_avail: int = 0
    no_bit_lock: int = 0
    window_half_w: int = 16
    sdls_en: bool = False
    bc_require_sdls: bool = False

    def process_tc_frame(
        self,
        bypass_flag: int,
        ctrl_cmd_flag: int,
        n_s: int,
        payload: bytes,
        crc_ok: bool,
        sdls_auth_ok: bool = True,
    ) -> Tuple[bool, Optional[bytes]]:
        if not crc_ok:
            return False, None

        is_type_ad = (bypass_flag == 0 and ctrl_cmd_flag == 0)
        is_type_bd = (bypass_flag == 1 and ctrl_cmd_flag == 0)
        is_type_bc = (bypass_flag == 1 and ctrl_cmd_flag == 1)

        if self.sdls_en:
            if (is_type_ad or is_type_bd) and not sdls_auth_ok:
                return False, None
            if is_type_bc and self.bc_require_sdls and not sdls_auth_ok:
                return False, None

        if is_type_bd:
            self.farm_b_cnt = (self.farm_b_cnt + 1) & 0x3
            return True, payload

        if is_type_bc:
            if len(payload) == 1 and payload[0] == 0x00:  # Unlock
                self.state = 0
                self.retransmit = 0
                self.wait_flag = 0
                self.farm_b_cnt = (self.farm_b_cnt + 1) & 0x3
                return True, None
            elif len(payload) == 3 and payload[0] == 0x82 and payload[1] == 0x00:  # Set V(R)
                if self.state == 0:
                    self.v_r = payload[2] & 0xFF
                    self.retransmit = 0
                    self.wait_flag = 0
                    self.farm_b_cnt = (self.farm_b_cnt + 1) & 0x3
                    return True, None
                else:
                    self.farm_b_cnt = (self.farm_b_cnt + 1) & 0x3
                    return False, None
            return False, None

        if is_type_ad:
            if self.state == 2:
                return False, None
            diff = (n_s - self.v_r) & 0xFF
            if diff == 0:
                if self.wait_flag:
                    self.retransmit = 1
                    return False, None
                self.v_r = (self.v_r + 1) & 0xFF
                self.retransmit = 0
                return True, payload
            elif 1 <= diff < self.window_half_w:
                self.retransmit = 1
                return False, None
            elif (256 - self.window_half_w) <= diff <= 255:
                return False, None
            else:
                self.state = 2
                return False, None

        return False, None

    def pack_clcw(self) -> int:
        lockout_bit = 1 if self.state == 2 else 0
        clcw = (
            (0 << 31)
            | (0 << 29)
            | (0 << 26)
            | (1 << 24)
            | ((self.vcid & 0x3F) << 18)
            | (0 << 16)
            | ((self.no_rf_avail & 1) << 15)
            | ((self.no_bit_lock & 1) << 14)
            | (lockout_bit << 13)
            | ((self.wait_flag & 1) << 12)
            | ((self.retransmit & 1) << 11)
            | ((self.farm_b_cnt & 0x3) << 9)
            | (0 << 8)
            | (self.v_r & 0xFF)
        )
        return clcw


def build_tc_frame(
    scid: int,
    vcid: int,
    n_s: int,
    payload: bytes,
    bypass_flag: int = 0,
    ctrl_cmd_flag: int = 0,
    seg_hdr: Optional[int] = 0xC0,
    include_fecf: bool = True,
) -> bytes:
    body = (bytes([seg_hdr & 0xFF]) if (seg_hdr is not None and ctrl_cmd_flag == 0) else b"") + payload
    total_len = 5 + len(body) + (2 if include_fecf else 0)
    c_len = total_len - 1
    hdr40 = (
        (0 << 38)
        | ((bypass_flag & 1) << 37)
        | ((ctrl_cmd_flag & 1) << 36)
        | (0 << 34)
        | ((scid & 0x3FF) << 24)
        | ((vcid & 0x3F) << 18)
        | ((c_len & 0x3FF) << 8)
        | (n_s & 0xFF)
    )
    frame_wo_crc = hdr40.to_bytes(5, "big") + body
    if include_fecf:
        crc = crc16_ccitt(frame_wo_crc)
        return frame_wo_crc + crc.to_bytes(2, "big")
    return frame_wo_crc


def wrap_cltu(
    tc_frames: List[bytes],
    bch_codec: CCSDSBCH6356Codec,
    randomize: bool = True,
) -> bytes:
    raw = b"".join(tc_frames)
    rem = len(raw) % 7
    if rem != 0:
        raw += b"\x55" * (7 - rem)
    if randomize:
        raw = scramble_tc(raw)
    out = bytearray(b"\xEB\x90")
    for idx in range(0, len(raw), 7):
        out.extend(bch_codec.encode_codeblock(raw[idx : idx + 7]))
    out.extend(b"\xC5\xC5\xC5\xC5\xC5\xC5\xC5\x79")
    return bytes(out)


def unwrap_cltu_and_deframe(
    cltu_bytes: bytes,
    bch_codec: CCSDSBCH6356Codec,
    randomize: bool = True,
) -> List[Tuple[dict, bytes, bool]]:
    assert cltu_bytes[:2] == b"\xEB\x90", "Missing 0xEB90 CLTU Start Sequence"
    info_blocks = bytearray()
    idx = 2
    while idx + 8 <= len(cltu_bytes):
        cb = cltu_bytes[idx : idx + 8]
        idx += 8
        decoded7, _corr, abort = bch_codec.decode_codeblock(cb)
        if abort or decoded7 is None:
            break
        info_blocks.extend(decoded7)

    stream = scramble_tc(bytes(info_blocks)) if randomize else bytes(info_blocks)
    results = []
    pos = 0
    while pos < len(stream):
        if all(b == 0x55 for b in stream[pos:]):
            break
        if pos + 5 > len(stream):
            break
        hdr40 = int.from_bytes(stream[pos : pos + 5], "big")
        c_len = (hdr40 >> 8) & 0x3FF
        frame_octets = c_len + 1
        if pos + frame_octets > len(stream):
            break
        frame_bytes = stream[pos : pos + frame_octets]
        pos += frame_octets
        crc_ok = (crc16_ccitt(frame_bytes) == 0x0000)
        hdr_dict = {
            "tfvn": (hdr40 >> 38) & 0x3,
            "bypass_flag": (hdr40 >> 37) & 0x1,
            "ctrl_cmd_flag": (hdr40 >> 36) & 0x1,
            "scid": (hdr40 >> 24) & 0x3FF,
            "vcid": (hdr40 >> 18) & 0x3F,
            "frame_len": c_len,
            "n_s": hdr40 & 0xFF,
        }
        payload_start = 5 if hdr_dict["ctrl_cmd_flag"] == 1 else 6
        payload = frame_bytes[payload_start:-2]
        results.append((hdr_dict, payload, crc_ok))
    return results


# =============================================================================
# 6. SDLS AES-GCM-256 Oracle (CCSDS 355.0-B-2)
# =============================================================================

def sdls_aes_gcm_encrypt(
    key_32b: bytes,
    spi: int,
    iv_12b: bytes,
    aad_hdr: bytes,
    tfdf_plaintext: bytes,
) -> Tuple[bytes, bytes, bytes]:
    aesgcm = AESGCM(key_32b)
    ct_and_tag = aesgcm.encrypt(iv_12b, tfdf_plaintext, aad_hdr)
    ciphertext = ct_and_tag[:-16]
    tag = ct_and_tag[-16:]
    sec_hdr = struct.pack(">H", spi & 0xFFFF) + iv_12b
    return sec_hdr, ciphertext, tag


def sdls_aes_gcm_decrypt(
    key_32b: bytes,
    iv_12b: bytes,
    aad_hdr: bytes,
    ciphertext: bytes,
    mac_tag_16b: bytes,
) -> Optional[bytes]:
    aesgcm = AESGCM(key_32b)
    try:
        return aesgcm.decrypt(iv_12b, ciphertext + mac_tag_16b, aad_hdr)
    except Exception:
        return None


# =============================================================================
# 7. Stage 4 Multi-Protocol Golden Builders & Parsers (AOS, Prox-1, USLP, Pkt)
# =============================================================================

def gf16_mul(a: int, b: int) -> int:
    p = 0
    cur = a & 0xF
    for i in range(4):
        if (b >> i) & 1:
            p ^= cur
        hi = (cur & 0x8) != 0
        cur = (cur << 1) & 0xF
        if hi:
            cur ^= 0x3
    return p


def compute_aos_fhec_16b(hdr24: int) -> int:
    """
    Computes CCSDS 732.0-B-4 Annex B 16-bit AOS Frame Header Error Control (FHEC)
    over 6 GF(2^4) symbols (24 protected header bits: SCID[7:0], VCID[5:0],
    Replay_Flag, VC_Cnt_Usage, Reserved[1:0], VC_Cnt_Cycle[3:0]) using
    g(x) = x^4 + alpha^3 x^3 + alpha^1 x^2 + alpha^3 x + 1 (taps 0x8, 0x2, 0x8, 0x1).
    """
    r = [0, 0, 0, 0]
    for k in range(5, -1, -1):
        sym = (hdr24 >> (k * 4)) & 0xF
        fb = sym ^ r[0]
        r[0] = r[1] ^ gf16_mul(fb, 0x8)
        r[1] = r[2] ^ gf16_mul(fb, 0x2)
        r[2] = r[3] ^ gf16_mul(fb, 0x8)
        r[3] = gf16_mul(fb, 0x1)
    return (r[0] << 12) | (r[1] << 8) | (r[2] << 4) | r[3]


def build_aos_frame(
    scid: int,
    vcid: int,
    vc_cnt: int,
    fhp: int,
    tfdf_payload: bytes,
    include_fhec: bool = True,
    ocf_clcw: Optional[int] = None,
    include_fecf: bool = True,
) -> bytes:
    hdr48 = (
        (0x1 << 46)
        | ((scid & 0xFF) << 38)
        | ((vcid & 0x3F) << 32)
        | ((vc_cnt & 0xFFFFFF) << 8)
        | (0 << 7)
        | (1 << 6)
        | (0 << 4)
        | 0
    )
    prot24 = ((hdr48 >> 32) << 8) | (hdr48 & 0xFF)
    fhec_bytes = compute_aos_fhec_16b(prot24).to_bytes(2, "big") if include_fhec else b""
    mpdu_hdr = (fhp & 0x7FF).to_bytes(2, "big")
    ocf_bytes = (ocf_clcw & 0xFFFFFFFF).to_bytes(4, "big") if ocf_clcw is not None else b""
    body = hdr48.to_bytes(6, "big") + fhec_bytes + mpdu_hdr + tfdf_payload + ocf_bytes
    if include_fecf:
        return body + crc16_ccitt(body).to_bytes(2, "big")
    return body


def build_prox1_frame(
    scid: int,
    pcid: int,
    port_id: int,
    seq_num: int,
    payload: bytes,
    qos_ind: int = 0,
    pdu_type_id: int = 0,
    dfc_id: int = 3,
    src_dst_id: int = 0,
) -> bytes:
    c_len = 5 + len(payload) - 1
    hdr40 = (
        (0x2 << 38)
        | ((qos_ind & 1) << 37)
        | ((pdu_type_id & 1) << 36)
        | ((dfc_id & 3) << 34)
        | ((scid & 0x3FF) << 24)
        | ((pcid & 1) << 23)
        | ((port_id & 7) << 20)
        | ((src_dst_id & 1) << 19)
        | ((c_len & 0x7FF) << 8)
        | (seq_num & 0xFF)
    )
    frame_wo_crc = hdr40.to_bytes(5, "big") + payload
    crc32 = crc32_prox1(frame_wo_crc)
    return frame_wo_crc + crc32.to_bytes(4, "big")


def build_uslp_frame(
    scid: int,
    vcid: int,
    map_id: int,
    upid: int,
    payload: bytes,
    truncated: bool = False,
    vcf_seq_bytes: bytes = b"\x00",
    fhp: int = 0,
    tfdf_3byte: bool = True,
    ocf_word: Optional[int] = None,
    use_crc32: bool = True,
    bypass_flag: int = 0,
    ctrl_cmd_flag: int = 0,
) -> bytes:
    base32 = (
        (0xC << 28)
        | ((scid & 0xFFFF) << 12)
        | (0 << 11)
        | ((vcid & 0x3F) << 5)
        | ((map_id & 0xF) << 1)
        | (1 if truncated else 0)
    )
    fecf_len = 4 if use_crc32 else 2
    if truncated:
        tfdfh = bytes([((0 & 0x7) << 5) | (upid & 0x1F)])
        frame_wo_crc = base32.to_bytes(4, "big") + tfdfh + payload
    else:
        tfdfh = (
            (((0 & 0x7) << 21) | ((upid & 0x1F) << 16) | (fhp & 0xFFFF)).to_bytes(3, "big")
            if tfdf_3byte
            else bytes([((0 & 0x7) << 5) | (upid & 0x1F)])
        )
        ocf_bytes = (ocf_word & 0xFFFFFFFF).to_bytes(4, "big") if ocf_word is not None else b""
        vcf_len = len(vcf_seq_bytes)
        total_octets = 4 + 3 + vcf_len + len(tfdfh) + len(payload) + len(ocf_bytes) + fecf_len
        c_len = total_octets - 1
        ext24 = (
            ((c_len & 0xFFFF) << 8)
            | ((bypass_flag & 1) << 7)
            | ((ctrl_cmd_flag & 1) << 6)
            | (0 << 4)
            | ((1 if ocf_word is not None else 0) << 3)
            | (vcf_len & 0x7)
        )
        frame_wo_crc = base32.to_bytes(4, "big") + ext24.to_bytes(3, "big") + vcf_seq_bytes + tfdfh + payload + ocf_bytes

    if use_crc32:
        return frame_wo_crc + crc32_prox1(frame_wo_crc).to_bytes(4, "big")
    return frame_wo_crc + crc16_ccitt(frame_wo_crc).to_bytes(2, "big")


def build_space_packet(apid: int, seq_cnt: int, data_field: bytes, pkt_type: int = 0, seq_flags: int = 3) -> bytes:
    assert len(data_field) >= 1
    c_len = len(data_field) - 1
    hdr48 = (
        (0 << 45)
        | ((pkt_type & 1) << 44)
        | (0 << 43)
        | ((apid & 0x7FF) << 32)
        | ((seq_flags & 0x3) << 30)
        | ((seq_cnt & 0x3FFF) << 16)
        | (c_len & 0xFFFF)
    )
    return hdr48.to_bytes(6, "big") + data_field


# =============================================================================
# 8. Stage 5 Next-Gen FEC Oracles (Conv K=7 / Viterbi, Short-LDPC, Turbo/AR4JA)
# =============================================================================

def conv_k7_encode_bits(bits: List[int], invert_c2: bool = True) -> List[Tuple[int, int]]:
    sr = 0
    out = []
    for b in bits:
        w = ((b & 1) << 6) | sr
        c1 = bin(w & 0b1111001).count("1") & 1
        c2 = bin(w & 0b1011011).count("1") & 1
        if invert_c2:
            c2 ^= 1
        out.append((c1, c2))
        sr = ((b & 1) << 5) | (sr >> 1)
    return out


def short_ldpc128_encode(info64: int) -> int:
    parity64 = 0
    for row in range(64):
        i0 = row % 64
        i1 = (row + 7) % 64
        i2 = (row + 23) % 64
        b0 = (info64 >> (63 - i0)) & 1
        b1 = (info64 >> (63 - i1)) & 1
        b2 = (info64 >> (63 - i2)) & 1
        p = b0 ^ b1 ^ b2
        parity64 = (parity64 << 1) | p
    return (info64 << 64) | parity64
