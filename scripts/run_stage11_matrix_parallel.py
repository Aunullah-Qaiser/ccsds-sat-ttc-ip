#!/usr/bin/env python3
"""
CCSDS-SAT-TTC-IP v2.39.0 — 12-Thread Parallel Stage 11 5,760-Configuration
RF Matrix & Progressive OAT + Combined Mission Envelope Monte Carlo Runner
==========================================================================
Compiles and elaborates `tb_stage11_top_to_top_rf_link` once via Vivado `xvlog`
and `xelab`, provisions N isolated worker directories (default: 12 threads) so
`xsim.dir` lock files never collide, launches N parallel `xsim` worker processes
across all 5,760 valid CCSDS configurations x M Monte Carlo trials per
configuration, and aggregates per-configuration and per-profile (P0..P5)
statistics into `reports/stage11_rf_matrix_coverage.json`.
"""

import argparse
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

RTL_SRCS = [
    "rtl/ccsds_pkg.sv",
    "rtl/ccsds_crc_universal.sv",
    "rtl/ccsds_lfsr_scrambler.sv",
    "rtl/ccsds_cdc_fifo_ecc.sv",
    "rtl/ccsds_gf256_math.sv",
    "rtl/ccsds_asm_correlator.sv",
    "rtl/ccsds_bch6356_dec.sv",
    "rtl/ccsds_farm1_tmr.sv",
    "rtl/ccsds_vc_arbiter_mux.sv",
    "rtl/ccsds_dl_rs255_223_enc.sv",
    "rtl/ccsds_tc_uslp_deframer.sv",
    "rtl/ccsds_tm_aos_uslp_framer.sv",
    "rtl/ccsds_pkt_reassembler.sv",
    "rtl/ccsds_prox1_plcw_ctrl.sv",
    "rtl/ccsds_axi_lite_csr.sv",
    "rtl/ccsds_conv_viterbi_codec.sv",
    "rtl/ccsds_ul_short_ldpc_dec.sv",
    "rtl/ccsds_dl_turbo_ldpc_enc.sv",
    "rtl/ccsds_hcpd_ctrl.sv",
    "rtl/ccsds_sdls_engine.sv",
    "rtl/ccsds_pn_ranging.sv",
    "rtl/ccsds_phy_modem.sv",
    "rtl/ccsds_bch6356_enc.sv",
    "rtl/ccsds_tc_cltu_framer.sv",
    "rtl/ccsds_fop1_engine.sv",
    "rtl/ccsds_tm_aos_deframer.sv",
    "rtl/ccsds_dl_rs255_223_dec.sv",
    "rtl/ccsds_channel_impairment_model.sv",
    "rtl/ccsds_space_flight_channel_model.sv",
    "rtl/ccsds_sat_ttc_top.sv",
]

TB_TOP = "tb_stage11_top_to_top_rf_link"
TB_SRC = "tb/tb_stage11_top_to_top_rf_link.sv"
SNAPSHOT = f"{TB_TOP}_sim"

IMPAIRMENT_MODE_MAP = {
    "auto": 0,
    "progressive": 1,
    "combined": 2,
    "oat_only": 3,
}

CASE_RE = re.compile(
    r"\[MATRIX-CASE(PASS|FAIL)\]\s+cfg_idx=(\d+)\s+wf=(\d+)\(mod=(\d+),line=(\d+)\)\s+"
    r"band=(\d+)\s+ul_bytes=(\d+)\s+dl_bytes=(\d+)\(cadu=(\d+),obt=(\d+),rand=(\d+)\)\s+"
    r"ul_fec=(\d+)\s+dl_proto=(\d+)\s+sdls=(\d+)\s+trials=(\d+)/(\d+)\s+"
    r"pre_errs=(\d+)\s+post_errs=(\d+)\s+ul_iq=(\d+)\s+dl_iq=(\d+)"
)
PROF_RE = re.compile(
    r"\[TB-STAGE11-PROFILES\]\s+P0_CLEAN=(\d+)/(\d+)\s+P1_AWGN_FEC=(\d+)/(\d+)\s+"
    r"P2_DOPPLER_PN=(\d+)/(\d+)\s+P3_DELAY_MP=(\d+)/(\d+)\s+"
    r"P4_RF_ANALOG=(\d+)/(\d+)\s+P5_COMBINED_MC=(\d+)/(\d+)"
)
CHUNK_RE = re.compile(
    r"\[TB-STAGE11-CHUNK PASS\]\s+CHUNK_ID=(\d+)\s+passed=(\d+)\s+failed=(\d+)\s+"
    r"trials_pass=(\d+)\s+trials_fail=(\d+)\s+pre_fec_errs=(\d+)\s+post_fec_errs=(\d+)\s+"
    r"ul_pkts=(\d+)\s+dl_pkts=(\d+)\s+ul_bytes=(\d+)\s+dl_bytes=(\d+)\s+"
    r"total_ul_iq=(\d+)\s+total_dl_iq=(\d+)"
)


def run_cmd(cmd, cwd, log_file=None):
    use_shell = os.name == "nt"
    proc = subprocess.run(
        cmd,
        cwd=str(cwd),
        shell=use_shell,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if log_file is not None:
        log_file.write_text(proc.stdout, encoding="utf-8")
    return proc.returncode, proc.stdout


def q_plusarg(arg_str: str) -> str:
    return f'"{arg_str}"' if os.name == "nt" else arg_str


def run_worker(
    worker_id: int,
    num_workers: int,
    total_configs: int,
    mc_iters: int,
    imp_mode_int: int,
    repo_root: Path,
    base_xsim_dir: Path,
) -> dict:
    worker_dir = repo_root / "build" / "stage11_workers" / f"worker_{worker_id:02d}"
    if worker_dir.exists():
        shutil.rmtree(worker_dir, ignore_errors=True)
    worker_dir.mkdir(parents=True, exist_ok=True)
    (worker_dir / "sim_waves").mkdir(parents=True, exist_ok=True)

    shutil.copytree(base_xsim_dir, worker_dir / "xsim.dir")
    xsim_exe = "xsim.bat" if os.name == "nt" else "xsim"
    cmd = [
        xsim_exe,
        SNAPSHOT,
        "-R",
        "-testplusarg", q_plusarg(f"CHUNK_ID={worker_id}"),
        "-testplusarg", q_plusarg(f"NUM_CHUNKS={num_workers}"),
        "-testplusarg", q_plusarg(f"TOTAL_CFGS={total_configs}"),
        "-testplusarg", q_plusarg(f"MC_ITERS={mc_iters}"),
        "-testplusarg", q_plusarg(f"IMPAIRMENT_MODE={imp_mode_int}"),
    ]
    t0 = time.time()
    rc, out = run_cmd(cmd, cwd=worker_dir, log_file=worker_dir / "xsim_worker.log")
    elapsed = round(time.time() - t0, 2)

    cases = []
    for m in CASE_RE.finditer(out):
        cases.append(
            {
                "status": m.group(1),
                "cfg_idx": int(m.group(2)),
                "wf_idx": int(m.group(3)),
                "mod_mode": int(m.group(4)),
                "line_code": int(m.group(5)),
                "band_idx": int(m.group(6)),
                "ul_bytes": int(m.group(7)),
                "dl_bytes": int(m.group(8)),
                "dl_cadu_bytes": int(m.group(9)),
                "obt_en": int(m.group(10)),
                "tm_rand_en": int(m.group(11)),
                "ul_fec": "LDPC(128,64)" if int(m.group(12)) == 1 else "BCH(63,56)",
                "dl_proto": ["TM", "AOS", "USLP"][int(m.group(13))],
                "sdls_en": int(m.group(14)),
                "trials_passed": int(m.group(15)),
                "trials_total": int(m.group(16)),
                "pre_fec_errs": int(m.group(17)),
                "post_fec_errs": int(m.group(18)),
                "ul_iq_samples": int(m.group(19)),
                "dl_iq_samples": int(m.group(20)),
            }
        )

    prof_match = PROF_RE.search(out)
    profiles = {}
    if prof_match:
        p_names = [
            "P0_CLEAN_REF",
            "P1_OAT_AWGN_FEC",
            "P2_OAT_DOPPLER_PN",
            "P3_OAT_DELAY_MP",
            "P4_OAT_RF_ANALOG",
            "P5_COMBINED_MC",
        ]
        for idx, pname in enumerate(p_names):
            profiles[pname] = {
                "passed": int(prof_match.group(2 * idx + 1)),
                "total": int(prof_match.group(2 * idx + 2)),
            }

    chunk_match = CHUNK_RE.search(out)
    passed_banner = "[TB-STAGE11 PASS]" in out and rc == 0 and chunk_match is not None
    tail_lines = [ln.strip() for ln in out.splitlines() if ln.strip()][-15:]

    return {
        "worker_id": worker_id,
        "return_code": rc,
        "passed": passed_banner,
        "elapsed_sec": elapsed,
        "configs_passed": int(chunk_match.group(2)) if chunk_match else sum(1 for c in cases if c["status"] == "PASS"),
        "configs_failed": int(chunk_match.group(3)) if chunk_match else sum(1 for c in cases if c["status"] != "PASS"),
        "trials_passed": int(chunk_match.group(4)) if chunk_match else sum(c["trials_passed"] for c in cases),
        "trials_failed": int(chunk_match.group(5)) if chunk_match else 0,
        "pre_fec_errs": int(chunk_match.group(6)) if chunk_match else sum(c["pre_fec_errs"] for c in cases),
        "post_fec_errs": int(chunk_match.group(7)) if chunk_match else sum(c["post_fec_errs"] for c in cases),
        "ul_pkts": int(chunk_match.group(8)) if chunk_match else sum(c["trials_passed"] for c in cases),
        "dl_pkts": int(chunk_match.group(9)) if chunk_match else sum(c["trials_passed"] for c in cases),
        "ul_bytes": int(chunk_match.group(10)) if chunk_match else sum(c["ul_bytes"] for c in cases),
        "dl_bytes": int(chunk_match.group(11)) if chunk_match else sum(c["dl_bytes"] for c in cases),
        "total_ul_iq": int(chunk_match.group(12)) if chunk_match else sum(c["ul_iq_samples"] for c in cases),
        "total_dl_iq": int(chunk_match.group(13)) if chunk_match else sum(c["dl_iq_samples"] for c in cases),
        "profiles": profiles,
        "cases": cases,
        "tail_lines": tail_lines,
        "log_path": str((worker_dir / "xsim_worker.log").relative_to(repo_root)),
    }


def main():
    parser = argparse.ArgumentParser(
        description="Run 5,760-configuration Stage 11 Top-to-Top RF Link Matrix & Progressive OAT/Combined Monte Carlo across N parallel xsim threads."
    )
    parser.add_argument("--threads", type=int, default=12, help="Number of parallel xsim worker threads (default: 12)")
    parser.add_argument("--total-configs", type=int, default=5760, help="Total valid configurations to sweep (default: 5760)")
    parser.add_argument("--mc-iters", type=int, default=1, help="Monte Carlo trials per configuration (default: 1; use >=6 for full OAT P0..P4 + Combined P5 per config)")
    parser.add_argument(
        "--impairment-mode",
        choices=["auto", "progressive", "combined", "oat_only"],
        default="auto",
        help="Channel impairment progression mode across trials (default: auto)",
    )
    parser.add_argument("--skip-compile", action="store_true", help="Reuse existing xsim.dir snapshot without running xvlog/xelab")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    (repo_root / "sim_waves").mkdir(parents=True, exist_ok=True)
    (repo_root / "reports").mkdir(parents=True, exist_ok=True)

    xvlog_exe = "xvlog.bat" if os.name == "nt" else "xvlog"
    xelab_exe = "xelab.bat" if os.name == "nt" else "xelab"

    t_start = time.time()
    if not args.skip_compile:
        print(f"[STAGE11-PARALLEL] Step 1/3: Compiling RTL + {TB_SRC} via {xvlog_exe}...")
        rc, out = run_cmd([xvlog_exe, "-sv", "-i", "rtl"] + RTL_SRCS + [TB_SRC], cwd=repo_root)
        if rc != 0:
            print(out)
            sys.exit(rc)

        print(f"[STAGE11-PARALLEL] Step 2/3: Elaborating snapshot '{SNAPSHOT}' via {xelab_exe}...")
        rc, out = run_cmd(
            [xelab_exe, "-timescale", "1ns/1ps", "-debug", "typical", TB_TOP, "-s", SNAPSHOT],
            cwd=repo_root,
        )
        if rc != 0:
            print(out)
            sys.exit(rc)

    base_xsim_dir = repo_root / "xsim.dir"
    if not base_xsim_dir.exists():
        print(f"[STAGE11-PARALLEL][ERROR] Elaborated directory not found: {base_xsim_dir}")
        sys.exit(1)

    num_workers = max(1, min(args.total_configs, args.threads))
    imp_mode_int = IMPAIRMENT_MODE_MAP[args.impairment_mode]
    total_trials_expected = args.total_configs * args.mc_iters

    print(
        f"[STAGE11-PARALLEL] Step 3/3: Launching {num_workers} parallel xsim worker threads "
        f"({args.total_configs:,} valid CCSDS RF configurations x {args.mc_iters} MC trials/config = "
        f"{total_trials_expected:,} bidirectional trials / {total_trials_expected * 2:,} RF packet transfers, "
        f"impairment_mode={args.impairment_mode})..."
    )

    worker_results = []
    printed_err_log = False
    with concurrent.futures.ThreadPoolExecutor(max_workers=num_workers) as pool:
        future_map = {
            pool.submit(
                run_worker,
                wid,
                num_workers,
                args.total_configs,
                args.mc_iters,
                imp_mode_int,
                repo_root,
                base_xsim_dir,
            ): wid
            for wid in range(num_workers)
        }
        for fut in concurrent.futures.as_completed(future_map):
            res = fut.result()
            worker_results.append(res)
            status_str = "PASS" if res["passed"] else "FAIL"
            print(
                f"  -> [WORKER {res['worker_id']:02d}/{num_workers:02d}] {status_str} | "
                f"cfgs={res['configs_passed']}/{res['configs_passed'] + res['configs_failed']} | "
                f"trials={res['trials_passed']:,} | pre_errs={res['pre_fec_errs']:,} -> post_errs={res['post_fec_errs']} | "
                f"ul_iq={res['total_ul_iq']:,} | dl_iq={res['total_dl_iq']:,} | time={res['elapsed_sec']:.2f}s"
            )
            if not res["passed"] and not printed_err_log:
                printed_err_log = True
                print(f"     [WORKER {res['worker_id']:02d} LOG TAIL ({res['log_path']})]:")
                for ln in res.get("tail_lines", []):
                    print(f"       {ln}")

    worker_results.sort(key=lambda r: r["worker_id"])
    total_elapsed = round(time.time() - t_start, 2)

    all_passed = all(r["passed"] for r in worker_results)
    total_cfgs_passed = sum(r["configs_passed"] for r in worker_results)
    total_cfgs_failed = sum(r["configs_failed"] for r in worker_results)
    total_trials_passed = sum(r["trials_passed"] for r in worker_results)
    total_trials_failed = sum(r["trials_failed"] for r in worker_results)
    total_pre_errs = sum(r["pre_fec_errs"] for r in worker_results)
    total_post_errs = sum(r["post_fec_errs"] for r in worker_results)
    total_ul_pkts = sum(r["ul_pkts"] for r in worker_results)
    total_dl_pkts = sum(r["dl_pkts"] for r in worker_results)
    total_ul_bytes = sum(r["ul_bytes"] for r in worker_results)
    total_dl_bytes = sum(r["dl_bytes"] for r in worker_results)
    total_ul_iq = sum(r["total_ul_iq"] for r in worker_results)
    total_dl_iq = sum(r["total_dl_iq"] for r in worker_results)

    agg_profiles = {
        "P0_CLEAN_REF": {"passed": 0, "total": 0},
        "P1_OAT_AWGN_FEC": {"passed": 0, "total": 0},
        "P2_OAT_DOPPLER_PN": {"passed": 0, "total": 0},
        "P3_OAT_DELAY_MP": {"passed": 0, "total": 0},
        "P4_OAT_RF_ANALOG": {"passed": 0, "total": 0},
        "P5_COMBINED_MC": {"passed": 0, "total": 0},
    }
    for r in worker_results:
        for pname, pval in r.get("profiles", {}).items():
            if pname in agg_profiles:
                agg_profiles[pname]["passed"] += pval["passed"]
                agg_profiles[pname]["total"] += pval["total"]

    total_bits = (total_ul_bytes + total_dl_bytes) * 8
    post_fec_ber = (total_post_errs / total_bits) if total_bits > 0 else 0.0
    post_fec_fer = (total_trials_failed / (total_trials_passed + total_trials_failed)) if (total_trials_passed + total_trials_failed) > 0 else 0.0

    report_data = {
        "version": "v2.39.0",
        "testbench": TB_TOP,
        "threads": num_workers,
        "mc_iters_per_config": args.mc_iters,
        "impairment_mode": args.impairment_mode,
        "overall_passed": all_passed and (total_cfgs_passed == args.total_configs) and (total_cfgs_failed == 0),
        "total_valid_rf_configs_tested": total_cfgs_passed,
        "total_valid_rf_configs_failed": total_cfgs_failed,
        "expected_valid_rf_configs": args.total_configs,
        "coverage_pct": round((total_cfgs_passed / float(args.total_configs)) * 100.0, 2),
        "total_monte_carlo_trials_passed": total_trials_passed,
        "total_monte_carlo_trials_failed": total_trials_failed,
        "total_rf_packet_transfers": total_ul_pkts + total_dl_pkts,
        "total_ul_packets": total_ul_pkts,
        "total_dl_packets": total_dl_pkts,
        "total_ul_payload_bytes": total_ul_bytes,
        "total_dl_payload_bytes": total_dl_bytes,
        "total_ul_iq_samples": total_ul_iq,
        "total_dl_iq_samples": total_dl_iq,
        "total_pre_fec_injected_errs": total_pre_errs,
        "total_post_fec_bit_errs": total_post_errs,
        "empirical_post_fec_ber": post_fec_ber,
        "empirical_post_fec_fer": post_fec_fer,
        "profile_breakdown": agg_profiles,
        "wall_clock_sec": total_elapsed,
        "workers": worker_results,
    }

    report_path = repo_root / "reports" / "stage11_rf_matrix_coverage.json"
    report_path.write_text(json.dumps(report_data, indent=2), encoding="utf-8")

    print("=" * 92)
    print(
        f"[STAGE11-PARALLEL SUMMARY] Status={'PASS' if report_data['overall_passed'] else 'FAIL'} | "
        f"Valid Configs={total_cfgs_passed:,}/{args.total_configs:,} ({report_data['coverage_pct']}%) | "
        f"MC Trials={total_trials_passed:,}/{total_trials_expected:,} | "
        f"RF Packets={total_ul_pkts + total_dl_pkts:,} ({total_ul_pkts:,} UL + {total_dl_pkts:,} DL)"
    )
    print(
        f"[STAGE11-PARALLEL FEC/BER] Pre-FEC Channel Errors Corrected={total_pre_errs:,} | "
        f"Post-FEC Bit Errors={total_post_errs} (BER={post_fec_ber:.2e}, FER={post_fec_fer:.2e})"
    )
    print(
        f"[STAGE11-PARALLEL PROFILES] "
        + " | ".join(f"{k}={v['passed']}/{v['total']}" for k, v in agg_profiles.items())
    )
    print(
        f"[STAGE11-PARALLEL METRICS] Uplink IQ={total_ul_iq:,} samples ({total_ul_bytes:,} SP bytes) | "
        f"Downlink IQ={total_dl_iq:,} samples ({total_dl_bytes:,} SP bytes) | Wall Time={total_elapsed:.2f}s"
    )
    print(f"[STAGE11-PARALLEL REPORT ] {report_path}")
    print("=" * 92)

    sys.exit(0 if report_data["overall_passed"] else 1)


if __name__ == "__main__":
    main()
