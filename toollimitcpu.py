import ctypes
import time
import psutil
import os
from ctypes import wintypes
from colorama import Fore, Style, init

init(autoreset=True)

# ================= SETTINGS =================
PROCESS_NAME = "RobloxPlayerBeta.exe"
CHECK_INTERVAL = 1

TOTAL_BUDGET = 85.0   # tổng CPU cho tất cả Roblox (%)
MIN_CAP = 0.0         # cap thấp nhất mỗi instance
MAX_CAP = 5.0         # cap cao nhất mỗi instance

RETRY_FAILED_ATTACH = True
CLEAR_SCREEN = True
# ===========================================

# WinAPI constants
JobObjectCpuRateControlInformation = 15
JOB_OBJECT_CPU_RATE_CONTROL_ENABLE = 0x1
JOB_OBJECT_CPU_RATE_CONTROL_HARD_CAP = 0x4

kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

class JOBOBJECT_CPU_RATE_CONTROL_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("ControlFlags", wintypes.DWORD),
        ("CpuRate", wintypes.DWORD)
    ]

def create_job_object(cpu_percent):
    job = kernel32.CreateJobObjectW(None, None)
    if not job:
        raise ctypes.WinError(ctypes.get_last_error())

    info = JOBOBJECT_CPU_RATE_CONTROL_INFORMATION()
    info.ControlFlags = JOB_OBJECT_CPU_RATE_CONTROL_ENABLE | JOB_OBJECT_CPU_RATE_CONTROL_HARD_CAP
    info.CpuRate = int(cpu_percent * 100)  # 100% = 10000

    ok = kernel32.SetInformationJobObject(
        job, JobObjectCpuRateControlInformation,
        ctypes.byref(info),
        ctypes.sizeof(info)
    )
    if not ok:
        raise ctypes.WinError(ctypes.get_last_error())

    return job

def attach_process(job, pid):
    PROCESS_ALL_ACCESS = 0x1F0FFF
    hProcess = kernel32.OpenProcess(PROCESS_ALL_ACCESS, False, pid)
    if not hProcess:
        return False, f"OpenProcess fail (err={ctypes.get_last_error()})"

    ok = kernel32.AssignProcessToJobObject(job, hProcess)
    kernel32.CloseHandle(hProcess)

    if not ok:
        err = ctypes.get_last_error()
        return False, f"Assign fail (err={err})"
    return True, "OK"

def find_roblox_pids():
    pids = []
    for p in psutil.process_iter(["pid", "name"]):
        try:
            if (p.info["name"] or "").lower() == PROCESS_NAME.lower():
                pids.append(p.info["pid"])
        except:
            pass
    return sorted(pids)

def clamp(x, lo, hi):
    return max(lo, min(hi, x))

def clear():
    if CLEAR_SCREEN:
        os.system("cls")

def header(instances, cap_each):
    print(Fore.CYAN + Style.BRIGHT + "=== ROBLOX AUTO CPU LIMIT (ADAPTIVE) ===")
    print(Fore.YELLOW + f"Target process: {PROCESS_NAME}")
    print(Fore.YELLOW + f"Instances running: {instances}")
    print(Fore.YELLOW + f"Total budget: {TOTAL_BUDGET:.1f}%")
    print(Fore.MAGENTA + Style.BRIGHT + f"Cap per instance (auto): {cap_each:.2f}%")
    print(Fore.WHITE + "-" * 60)

def print_table(pids, status_map, cap_each):
    print(Fore.WHITE + f"{'PID':<10}{'STATUS':<15}{'CAP':<10}{'CPU NOW':<10}")
    print(Fore.WHITE + "-" * 60)

    for pid in pids:
        cpu_now = 0.0
        try:
            proc = psutil.Process(pid)
            cpu_now = proc.cpu_percent(interval=0.05)
        except:
            pass

        st = status_map.get(pid, "UNKNOWN")

        if st == "LIMITED":
            st_col = Fore.GREEN + st
        elif st.startswith("FAILED"):
            st_col = Fore.RED + st
        else:
            st_col = Fore.YELLOW + st

        print(f"{pid:<10}{st_col:<15}{Fore.MAGENTA + f'{cap_each:.2f}%':<10}{Fore.CYAN + f'{cpu_now:.1f}%':<10}")

def main():
    limited = {}  # pid -> job handle
    failed = {}   # pid -> reason

    while True:
        pids = find_roblox_pids()
        n = len(pids)

        if n == 0:
            clear()
            print(Fore.CYAN + Style.BRIGHT + "=== ROBLOX AUTO CPU LIMIT (ADAPTIVE) ===")
            print(Fore.YELLOW + "Không thấy Roblox. Đang chờ mở Roblox...")
            time.sleep(CHECK_INTERVAL)
            continue

        # Auto cap calculation
        cap_each = clamp(TOTAL_BUDGET / n, MIN_CAP, MAX_CAP)

        # cleanup dead
        for pid in list(limited.keys()):
            if not psutil.pid_exists(pid):
                limited.pop(pid, None)
        for pid in list(failed.keys()):
            if not psutil.pid_exists(pid):
                failed.pop(pid, None)

        status_map = {}

        # Attach / limit each instance
        for pid in pids:
            if pid in limited:
                status_map[pid] = "LIMITED"
                continue

            # create job with cap_each and attach
            try:
                job = create_job_object(cap_each)
                ok, msg = attach_process(job, pid)
                if ok:
                    limited[pid] = job
                    status_map[pid] = "LIMITED"
                else:
                    failed[pid] = msg
                    status_map[pid] = "FAILED"
            except Exception as e:
                failed[pid] = str(e)
                status_map[pid] = "FAILED"

        # retry failed if enabled
        if RETRY_FAILED_ATTACH and failed:
            for pid in list(failed.keys()):
                if pid in limited or pid not in pids:
                    continue
                try:
                    job = create_job_object(cap_each)
                    ok, msg = attach_process(job, pid)
                    if ok:
                        limited[pid] = job
                        failed.pop(pid, None)
                        status_map[pid] = "LIMITED"
                except Exception:
                    pass

        # draw UI
        clear()
        header(n, cap_each)
        print_table(pids, status_map, cap_each)

        limited_count = sum(1 for pid in pids if status_map.get(pid) == "LIMITED")
        failed_count = n - limited_count

        print(Fore.WHITE + "-" * 60)
        print(Fore.GREEN + f"Limited: {limited_count}  " + Fore.RED + f"Failed: {failed_count}")
        print(Fore.WHITE + f"Expected TOTAL (max): ~{min(TOTAL_BUDGET, cap_each*n):.2f}%")
        if failed_count > 0:
            print(Fore.RED + "TIP: Nếu FAILED -> hãy chạy CMD bằng Administrator rồi mở Roblox lại.")
        print(Fore.WHITE + "-" * 60)

        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(Fore.CYAN + "\n[EXIT] Tool stopped.")

