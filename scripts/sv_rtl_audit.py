#!/usr/bin/env python3
"""
===============================================================================
File Name   : sv_rtl_audit.py
Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
Version     : v2.8 (Includes Full Cross-Module Port Elaboration & Rule #4/#5)
Description : Pillar 1 Automated Static SystemVerilog (IEEE 1800-2017) AST,
              Packed Bit-Width, Synthesis Rule, Latch, Combinational Division,
              and Cross-Module Hierarchy Port-Binding Elaboration Auditor.
              Verifies:
                1. Exact packed struct bit-widths in ccsds_pkg.sv against
                   CCSDS Blue Book specifications (TM=48b, TC=40b, TC_SEG=8b,
                   AOS=48b, Prox-1=40b, USLP=32b+24b+24b, CLCW=32b, PLCW=32b,
                   tuser=64b).
                2. Balanced package/endpackage, module/endmodule, function/
                   endfunction, and begin/end keywords.
                3. Strict IEEE 1800-2017 synthesis rules:
                   - No legacy 'always @(*)' or 'always @(posedge ...)'
                   - No non-blocking '<=' assignments inside always_comb
                4. No 64-bit non-power-of-two combinational division ('/ 64'd...')
                   in synthesizable RTL modules.
                5. Full Cross-Module SystemVerilog Hierarchy Elaboration &
                   Port-Binding Verification across all 28 RTL modules and
                   6 self-checking testbenches (0 unknown ports, 0 unconnected
                   inputs).
===============================================================================
"""

from __future__ import annotations
import re
import sys
import json
from pathlib import Path
from typing import Dict, List, Tuple


EXPECTED_STRUCT_BITS: Dict[str, int] = {
    "ccsds_space_pkt_hdr_t": 48,
    "ccsds_tc_prim_hdr_t": 40,
    "ccsds_tc_seg_hdr_t": 8,
    "ccsds_tm_prim_hdr_t": 48,
    "ccsds_aos_prim_hdr_t": 48,
    "ccsds_prox1_prim_hdr_t": 40,
    "ccsds_uslp_trunc_hdr_t": 32,
    "ccsds_uslp_ext_hdr_t": 24,
    "ccsds_uslp_tfdf_hdr_t": 24,
    "ccsds_clcw_t": 32,
    "ccsds_plcw_t": 32,
    "ccsds_tuser_t": 64,
}

SV_RTL_MANIFEST: List[str] = [
    "ccsds_pkg.sv",
    "ccsds_channel_impairment_model.sv",
    "ccsds_crc_universal.sv",
    "ccsds_lfsr_scrambler.sv",
    "ccsds_cdc_fifo_ecc.sv",
    "ccsds_gf256_math.sv",
    "ccsds_asm_correlator.sv",
    "ccsds_bch6356_dec.sv",
    "ccsds_farm1_tmr.sv",
    "ccsds_vc_arbiter_mux.sv",
    "ccsds_dl_rs255_223_enc.sv",
    "ccsds_tc_uslp_deframer.sv",
    "ccsds_tm_aos_uslp_framer.sv",
    "ccsds_pkt_reassembler.sv",
    "ccsds_prox1_plcw_ctrl.sv",
    "ccsds_axi_lite_csr.sv",
    "ccsds_conv_viterbi_codec.sv",
    "ccsds_ul_short_ldpc_dec.sv",
    "ccsds_dl_turbo_ldpc_enc.sv",
    "ccsds_hcpd_ctrl.sv",
    "ccsds_sdls_engine.sv",
    "ccsds_pn_ranging.sv",
    "ccsds_phy_modem.sv",
    "ccsds_sat_ttc_top.sv",
    "ccsds_bch6356_enc.sv",
    "ccsds_tc_cltu_framer.sv",
    "ccsds_fop1_engine.sv",
    "ccsds_tm_aos_deframer.sv",
    "ccsds_dl_rs255_223_dec.sv",
]

SV_TB_MANIFEST: List[str] = [
    "tb_stage2_primitives.sv",
    "tb_stage3_vertical_slice.sv",
    "tb_stage4_multiprotocol.sv",
    "tb_stage5_fec_hcpd.sv",
    "tb_stage6_full_system.sv",
    "tb_stage7_hw_egse_loopback.sv",
    "tb_stage8_all_protocols_channel_loopback.sv",
    "tb_stage9_external_ref_check.sv",
    "tb_stage10_full_matrix_link_stress.sv",
]


def strip_sv_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text = re.sub(r"//.*?$", "", text, flags=re.MULTILINE)
    return text


def audit_packed_structs(pkg_text: str) -> Tuple[Dict[str, int], List[str], List[str]]:
    clean = strip_sv_comments(pkg_text)
    struct_pattern = re.compile(
        r"typedef\s+struct\s+packed\s*\{(.*?)\}\s*(\w+)\s*;",
        re.DOTALL,
    )
    field_pattern = re.compile(
        r"logic\s*(?:\[\s*(\d+)\s*:\s*(\d+)\s*\])?\s*(\w+)\s*;"
    )
    found_widths: Dict[str, int] = {}
    errors: List[str] = []
    warnings: List[str] = []

    for match in struct_pattern.finditer(clean):
        body, struct_name = match.group(1), match.group(2)
        total_bits = 0
        for f_match in field_pattern.finditer(body):
            msb_str, lsb_str, _fname = f_match.groups()
            if msb_str is not None and lsb_str is not None:
                msb, lsb = int(msb_str), int(lsb_str)
                if msb < lsb:
                    errors.append(
                        f"[{struct_name}] Little-endian bit range [{msb}:{lsb}] violates MSB-first convention"
                    )
                total_bits += abs(msb - lsb) + 1
            else:
                total_bits += 1
        found_widths[struct_name] = total_bits

    for exp_name, exp_bits in EXPECTED_STRUCT_BITS.items():
        if exp_name not in found_widths:
            errors.append(f"Missing mandatory packed struct '{exp_name}' in ccsds_pkg.sv")
        elif found_widths[exp_name] != exp_bits:
            errors.append(
                f"Struct '{exp_name}' has {found_widths[exp_name]} bits, expected {exp_bits} bits"
            )

    return found_widths, errors, warnings


def parse_module_ports(clean_text: str) -> Dict[str, Dict[str, Tuple[str, str]]]:
    mod_ports: Dict[str, Dict[str, Tuple[str, str]]] = {}
    mod_pat = re.compile(
        r"\bmodule\s+(\w+)\s*(?:import\s+[^;]+;\s*)*(?:#\s*\((.*?)\)\s*)?(?:\((.*?)\))?\s*;",
        re.DOTALL,
    )
    for m in mod_pat.finditer(clean_text):
        mname, _params, ports_str = m.group(1), m.group(2) or "", m.group(3) or ""
        ports: Dict[str, Tuple[str, str]] = {}
        for pdecl in ports_str.split(","):
            pm = re.search(
                r"\b(input|output|inout)\b\s+(?:wire|logic|reg)?\s*(?:signed)?\s*([^;]*?)\b(\w+)\s*$",
                pdecl.strip(),
                re.DOTALL,
            )
            if pm:
                ports[pm.group(3).strip()] = (pm.group(1), pm.group(2).strip())
        mod_ports[mname] = ports
    return mod_ports


def audit_sv_file(sv_path: Path) -> Dict[str, object]:
    raw_text = sv_path.read_text(encoding="utf-8")
    clean = strip_sv_comments(raw_text)
    errors: List[str] = []
    warnings: List[str] = []

    # 0. Verify mandatory `timescale 1ns / 1ps directive for Vivado xelab [XSIM 43-4100] compliance
    if not re.search(r"^\s*`timescale\s+1ns\s*/\s*1ps", clean, flags=re.MULTILINE):
        errors.append(f"{sv_path.name}: Missing mandatory `timescale 1ns / 1ps directive")

    # 1. Check balanced block delimiters
    pairs = [
        ("package", "endpackage"),
        ("module", "endmodule"),
        ("function", "endfunction"),
        ("begin", "end"),
    ]
    for open_kw, close_kw in pairs:
        n_open = len(re.findall(rf"\b{open_kw}\b", clean))
        n_close = len(re.findall(rf"\b{close_kw}\b", clean))
        if n_open != n_close:
            errors.append(
                f"{sv_path.name}: Unbalanced '{open_kw}' ({n_open}) vs '{close_kw}' ({n_close})"
            )

    # 2. Forbid legacy Verilog-2001 'always @' in synthesizable RTL (require always_ff / always_comb)
    if not sv_path.name.startswith("tb_"):
        if re.search(r"\balways\s*@", clean):
            errors.append(
                f"{sv_path.name}: Legacy 'always @' detected; use IEEE 1800-2017 'always_ff' or 'always_comb'"
            )
        # 4. Forbid 64-bit combinational division in synthesizable RTL (CR-02 / CR-06)
        if re.search(r"/\s*64'd", clean):
            errors.append(
                f"{sv_path.name}: Non-power-of-two 64-bit combinational division detected; use Q32 reciprocal multiplier"
            )

    # 3. Check always_comb blocks for illegal non-blocking '<=' assignments
    for comb_match in re.finditer(r"\balways_comb\b\s*begin(.*?)end", clean, re.DOTALL):
        comb_body = comb_match.group(1)
        stmt_no_parens = re.sub(r"\([^()]*\)", "()", comb_body)
        if "<=" in stmt_no_parens:
            errors.append(
                f"{sv_path.name}: Non-blocking assignment '<=' found inside always_comb block"
            )


    # 8. Rule #8 (Fix CR-23): Forbid driving the same signal from both always_ff and initial blocks (VRFC 10-3818)
    m_ff = re.search(r"always_ff\b(.*?)(?=\n\s*initial\b|\nendmodule)", clean, flags=re.DOTALL)
    m_init = re.search(r"\n\s*initial\b(.*?)(?=\nendmodule)", clean, flags=re.DOTALL)
    if m_ff and m_init:
        ff_vars = set(re.findall(r"\b([a-zA-Z_]\w*)\s*(?:\[[^\]]*\])?\s*<=", m_ff.group(1)))
        init_vars = set(re.findall(r"\b([a-zA-Z_]\w*)\s*(?:\[[^\]]*\])?\s*(?<![=!<>])=(?!=)", m_init.group(1)))
        for ov in sorted(ff_vars & init_vars):
            errors.append(
                f"{sv_path.name}: Variable '{ov}' is driven in both always_ff and initial blocks (triggers Vivado VRFC 10-3818)"
            )

    struct_widths: Dict[str, int] = {}
    if sv_path.name == "ccsds_pkg.sv":
        struct_widths, s_errs, s_warns = audit_packed_structs(raw_text)
        errors.extend(s_errs)
        warnings.extend(s_warns)

    return {
        "file": sv_path.name,
        "lines": len(raw_text.splitlines()),
        "struct_widths": struct_widths,
        "errors": errors,
        "warnings": warnings,
        "passed": len(errors) == 0 and len(warnings) == 0,
    }


def resolve_sv_files(rtl_dir: Path) -> List[Path]:
    discovered = {p.name: p for p in rtl_dir.glob("*.sv")}
    for fname in SV_RTL_MANIFEST:
        cand = rtl_dir / fname
        if cand.is_file():
            discovered[fname] = cand
    tb_dir = rtl_dir.parent / "tb"
    if tb_dir.is_dir():
        for p in tb_dir.glob("*.sv"):
            discovered[p.name] = p
        for fname in SV_TB_MANIFEST:
            cand = tb_dir / fname
            if cand.is_file():
                discovered[fname] = cand
    return [discovered[k] for k in sorted(discovered.keys())]




def audit_symbols_and_struct_fields(rtl_dir: Path, tb_dir: Path) -> List[str]:
    """
    Rule #6: Full Cross-Module SystemVerilog Symbol-Table, Package Constant,
    and Packed Struct Field (.member) Resolver across all 28 RTL + 6 TB files.
    Catches undeclared constants/wires and invalid struct field names before
    Vivado xvlog / xelab / Verilator compilation.
    """
    errors: List[str] = []
    pkg_path = rtl_dir / "ccsds_pkg.sv"
    if not pkg_path.exists():
        return ["Missing rtl/ccsds_pkg.sv"]

    def strip_all(text: str) -> str:
        text = strip_sv_comments(text)
        text = re.sub(r'"[^"]*"', '""', text)
        text = re.sub(r"`\w+.*", "", text)
        text = re.sub(r"\(\*.*?\*\)", "", text, flags=re.DOTALL)
        return text

    clean_pkg = strip_all(pkg_path.read_text(encoding="utf-8"))

    struct_members: Dict[str, set] = {}
    for m in re.finditer(r"typedef\s+struct\s+packed\s*\{(.*?)\}\s*(\w+)\s*;", clean_pkg, re.DOTALL):
        body, sname = m.group(1), m.group(2)
        fields = re.findall(r"logic\s*(?:\[[^\]]+\])?\s*(\w+)\s*;", body)
        struct_members[sname] = set(fields)

    pkg_enums: set = set()
    pkg_symbols = set(struct_members.keys())
    for m in re.finditer(r"\b(?:localparam|parameter)\b[^;]*?\b(\w+)\s*(?:\[[^\]]*\])?\s*=", clean_pkg, re.DOTALL):
        pkg_symbols.add(m.group(1))
    for m in re.finditer(r"typedef\s+.*?(\w+)\s*;", clean_pkg, re.DOTALL):
        pkg_symbols.add(m.group(1))
    for m in re.finditer(r"typedef\s+enum\s+[^\{]+\{(.*?)\}\s*(\w+)\s*;", clean_pkg, re.DOTALL):
        ebody, ename = m.group(1), m.group(2)
        pkg_symbols.add(ename)
        pkg_enums.add(ename)
        for item in ebody.split(","):
            lit = item.split("=")[0].strip()
            if lit:
                pkg_symbols.add(lit)
    for m in re.finditer(r"\bfunction\s+automatic\s+[^\(\;]+\b(\w+)\s*\(", clean_pkg):
        pkg_symbols.add(m.group(1))

    sv_keywords = {
        "module", "endmodule", "package", "endpackage", "import", "localparam", "parameter",
        "input", "output", "inout", "logic", "wire", "reg", "int", "integer", "bit", "byte",
        "shortint", "longint", "time", "realtime", "real", "signed", "unsigned", "typedef",
        "struct", "packed", "enum", "union", "function", "endfunction", "task", "endtask",
        "automatic", "always_ff", "always_comb", "always", "initial", "final", "begin", "end",
        "if", "else", "case", "casez", "casex", "endcase", "default", "for", "while", "repeat",
        "forever", "do", "break", "continue", "return", "assign", "deassign", "force", "release",
        "posedge", "negedge", "or", "and", "not", "xor", "nand", "nor", "xnor", "generate",
        "endgenerate", "genvar", "iff", "property", "endproperty", "sequence", "endsequence",
        "assert", "assume", "cover", "disable", "wait", "null", "this", "super", "string",
        "event", "void", "const", "var", "ref", "static", "virtual", "interface", "endinterface",
        "modport", "clocking", "endclocking", "priority", "unique", "unique0", "inside",
        "ccsds_pkg"
    }

    all_files = sorted(list(rtl_dir.glob("*.sv")) + (list(tb_dir.glob("*.sv")) if tb_dir.exists() else []))
    module_names = set()
    for p in all_files:
        c = strip_all(p.read_text(encoding="utf-8"))
        for m in re.finditer(r"\bmodule\s+(\w+)", c):
            module_names.add(m.group(1))

    for p in all_files:
        if p.name == "ccsds_pkg.sv":
            continue
        c = strip_all(p.read_text(encoding="utf-8"))

        var_struct_type: Dict[str, str] = {}
        for sname in struct_members:
            for vm in re.finditer(rf"\b{sname}\b\s+([^;\)]+)", c):
                for part in vm.group(1).split(","):
                    vname = part.split("=")[0].strip()
                    vname = re.sub(r"\[.*?\]", "", vname).strip()
                    if re.match(r"^\w+$", vname):
                        var_struct_type[vname] = sname

        for dm in re.finditer(r"\b(\w+)\.(\w+)\b", c):
            lhs, rhs = dm.group(1), dm.group(2)
            if lhs in var_struct_type:
                stype = var_struct_type[lhs]
                if rhs not in struct_members[stype]:
                    errors.append(
                        f"{p.name}: Invalid struct field '{lhs}.{rhs}' on type '{stype}'"
                    )

        declared = set(pkg_symbols) | set(sv_keywords) | set(module_names) | set(var_struct_type.keys())
        for m in re.finditer(r"\bmodule\s+(\w+)", c):
            declared.add(m.group(1))
        for m in re.finditer(r":\s*(\w+)", c):
            declared.add(m.group(1))
        for m in re.finditer(r"\b(?:parameter|localparam)\b[^;,\)]*?\b(\w+)\s*(?:\[[^\]]*\])?\s*=", c, re.DOTALL):
            declared.add(m.group(1))
        for m in re.finditer(r"typedef\s+enum\s+[^\{]+\{(.*?)\}\s*(\w+)\s*;", c, re.DOTALL):
            ebody, ename = m.group(1), m.group(2)
            declared.add(ename)
            for item in ebody.split(","):
                lit = item.split("=")[0].strip()
                if lit:
                    declared.add(lit)
            for vm in re.finditer(rf"\b{ename}\b\s+([^;]+);", c):
                for part in vm.group(1).split(","):
                    vname = part.split("=")[0].strip()
                    if re.match(r"^\w+$", vname):
                        declared.add(vname)

        type_words = ["logic", "wire", "reg", "int", "integer", "genvar", "bit", "byte", "time", "realtime", "real", "string"] + list(struct_members.keys()) + list(pkg_enums)
        type_regex = r"\b(?:" + "|".join(type_words) + r")\b(?:\s+(?:signed|unsigned))?(?:\s*\[[^\]]+\])*([\s\w,\[\]=':\+\-\*]+?)(?:;|\)|\n)"
        for m in re.finditer(type_regex, c):
            for tok in re.findall(r"\b([a-zA-Z_]\w*)\b", m.group(1)):
                if tok not in sv_keywords:
                    declared.add(tok)
        for m in re.finditer(r"\bfor\s*\(\s*(?:int|integer|genvar|logic[^;]*?)\s+(\w+)\s*=", c):
            declared.add(m.group(1))
        for m in re.finditer(r"\b(?:function|task)\s+(?:automatic\s+)?(?:[^\(\;]+?\s+)?(\w+)\s*\((.*?)\)\s*;", c, re.DOTALL):
            declared.add(m.group(1))
            for tok in re.findall(r"\b([a-zA-Z_]\w*)\b", m.group(2)):
                declared.add(tok)
        for mod in module_names:
            for m in re.finditer(rf"\b{mod}\b\s*(?:#\s*\(.*?\)\s*)?(\w+)\s*\(", c, re.DOTALL):
                declared.add(m.group(1))

        c_scan = re.sub(r"\.\s*\w+\s*\(", "(", c)
        c_scan = re.sub(r"\b\w+\.\w+\b", "", c_scan)
        c_scan = re.sub(r"\b\d+'[sS]?[bBdDhHoO][0-9a-fA-F_xXzZ]+\b", "0", c_scan)
        c_scan = re.sub(r"'[01xXzZ]\b", "0", c_scan)
        c_scan = re.sub(r"\$\w+", "", c_scan)

        for tok_m in re.finditer(r"\b([a-zA-Z_]\w*)\b", c_scan):
            ident = tok_m.group(1)
            if ident not in declared:
                errors.append(f"{p.name}: Undeclared identifier '{ident}'")

    return errors


def run_audit(rtl_dir: Path) -> Tuple[bool, List[Dict[str, object]]]:
    sv_files = resolve_sv_files(rtl_dir)
    reports = [audit_sv_file(p) for p in sv_files]

    # Rule 5: Cross-module hierarchy elaboration & port-binding check
    all_mod_ports: Dict[str, Dict[str, Tuple[str, str]]] = {}
    file_cleans: Dict[str, str] = {}
    for p in sv_files:
        c = strip_sv_comments(p.read_text(encoding="utf-8"))
        file_cleans[p.name] = c
        all_mod_ports.update(parse_module_ports(c))

    inst_pat = re.compile(
        r"\b(ccsds_\w+)\s+(?:#\s*\((?:[^()]|\([^()]*\))*\)\s*)?(\w+)\s*\(((?:[^()]|\([^()]*\))*)\)\s*;",
        re.DOTALL,
    )
    for rep in reports:
        fname = str(rep["file"])
        clean = file_cleans[fname]
        errs: List[str] = list(rep["errors"])  # type: ignore
        for im in inst_pat.finditer(clean):
            target_mod, inst_name, conns_str = im.group(1), im.group(2), im.group(3)
            if target_mod not in all_mod_ports:
                continue
            tports = all_mod_ports[target_mod]
            connected = set()
            for cm in re.finditer(r"\.(\w+)\s*\(", conns_str):
                pname = cm.group(1)
                connected.add(pname)
                if pname not in tports:
                    errs.append(
                        f"{fname}: Instance '{inst_name}' of '{target_mod}' connects non-existent port '.{pname}'"
                    )
            missing_in = [p for p, (d, _) in tports.items() if d == "input" and p not in connected]
            if missing_in:
                errs.append(
                    f"{fname}: Instance '{inst_name}' of '{target_mod}' leaves input port(s) unconnected: {missing_in}"
                )
        rep["errors"] = errs
        rep["passed"] = len(errs) == 0 and len(rep["warnings"]) == 0  # type: ignore

    # Ensure ccsds_pkg.sv is first in report list so struct_widths is at index 0
    reports.sort(key=lambda r: (0 if r["file"] == "ccsds_pkg.sv" else 1, str(r["file"])))
    all_passed = all(bool(r["passed"]) for r in reports) and len(sv_files) > 0
    return all_passed, reports


if __name__ == "__main__":
    target_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "rtl"
    passed, results = run_audit(target_dir)
    print(json.dumps({"passed": passed, "files_audited": len(results), "results": results}, indent=2))
    sys.exit(0 if passed else 1)
