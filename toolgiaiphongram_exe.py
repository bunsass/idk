import time
import ctypes
import psutil
import json
import os
import sys
from colorama import Fore, init

init(autoreset=True)

# ============== CREDIT ==============
AUTHOR = "DwyDuy"
DISCORD = "discord.gg/sVPNHz7s"
VERSION = "1.0"
# ====================================

PROCESS_ALL_ACCESS = 0x1F0FFF
DEFAULT_RAM_INTERVAL = 10
DEFAULT_PROCESS_NAME = "RobloxPlayerBeta.exe"

def print_banner():
    banner = f"""
{Fore.CYAN}╔══════════════════════════════════════════════════════════╗
{Fore.CYAN}║{Fore.MAGENTA}     ____          _     _              ____    _    __  __ {Fore.CYAN}║
{Fore.CYAN}║{Fore.MAGENTA}    |  _ \\ ___  __| | __| | _____  __  |  _ \\  / \\  |  \\/  |{Fore.CYAN}║
{Fore.CYAN}║{Fore.MAGENTA}    | |_) / _ \\/ _` |/ _` |/ _ \\ \\/ /  | |_) |/ _ \\ | |\\/| |{Fore.CYAN}║
{Fore.CYAN}║{Fore.MAGENTA}    |  _ < (_) | (_| | (_| |  __/>  <   |  _ </ ___ \\| |  | |{Fore.CYAN}║
{Fore.CYAN}║{Fore.MAGENTA}    |_| \\_\\___/ \\__,_|\\__,_|\\___/_/\\_\\  |_| \\_\\_/   \\_\\_|  |_|{Fore.CYAN}║
{Fore.CYAN}║{Fore.WHITE}                   Tool Giai Phong RAM Roblox              {Fore.CYAN}║
{Fore.CYAN}╠══════════════════════════════════════════════════════════╣
{Fore.CYAN}║{Fore.GREEN}  Credit: {Fore.YELLOW}{AUTHOR:<20}{Fore.GREEN}Version: {Fore.YELLOW}{VERSION:<16}{Fore.CYAN}║
{Fore.CYAN}║{Fore.GREEN}  Discord: {Fore.YELLOW}{DISCORD:<45}{Fore.CYAN}║
{Fore.CYAN}╚══════════════════════════════════════════════════════════╝
"""
    print(banner)

def get_resource_path(filename):
    """Lấy đường dẫn file khi chạy từ exe hoặc script"""
    if getattr(sys, 'frozen', False):
        # Chạy từ exe
        return os.path.join(os.path.dirname(sys.executable), filename)
    else:
        # Chạy từ script
        return os.path.join(os.path.dirname(os.path.abspath(__file__)), filename)

class RamMonitorOptimized:
    def __init__(self, config_file="config.json"):

        self.ram_interval = DEFAULT_RAM_INTERVAL
        self.process_name = DEFAULT_PROCESS_NAME

        config_path = get_resource_path(config_file)

        try:
            with open(config_path, 'r') as f:
                config_data = json.load(f)

                times_value = config_data.get("times")
                if isinstance(times_value, (int, float)) and times_value > 0:
                    self.ram_interval = times_value
                else:
                    print(Fore.YELLOW + f"[WARN] Gia tri 'times' khong hop le hoac thieu. Su dung mac dinh: {DEFAULT_RAM_INTERVAL}s.")

        except FileNotFoundError:
            print(Fore.YELLOW + f"[WARN] Khong tim thay file cau hinh. Su dung cai dat mac dinh: {DEFAULT_RAM_INTERVAL}s")
        except json.JSONDecodeError:
            print(Fore.RED + f"[ERROR] Loi dinh dang JSON trong file config. Su dung cai dat mac dinh")
        except Exception as e:
            print(Fore.RED + f"[ERROR] Loi khong xac dinh: {e}. Su dung cai dat mac dinh")

        self.tracked = set()

        print(Fore.CYAN + "[INIT] Khoi tao RAM Monitor")
        print(Fore.YELLOW + f"  - Thoi gian giai phong: {self.ram_interval} giay")
        print(Fore.YELLOW + f"  - Process: {self.process_name}")
        print()

    def get_roblox_pids(self):
        pids = set()
        for p in list(psutil.process_iter(["pid", "name"])):
            try:
                if (p.info["name"] or "").lower() == self.process_name.lower():
                    pids.add(p.info["pid"])
            except (psutil.NoSuchProcess, psutil.AccessDenied, ValueError):
                pass
        return pids

    def release_ram(self):
        released_count = 0
        for p in psutil.process_iter(["pid", "name"]):
            try:
                if (p.info["name"] or "").lower() != self.process_name.lower():
                    continue

                h = ctypes.windll.kernel32.OpenProcess(PROCESS_ALL_ACCESS, False, p.info["pid"])

                if h:
                    ctypes.windll.psapi.EmptyWorkingSet(h)
                    ctypes.windll.kernel32.CloseHandle(h)
                    released_count += 1
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
            except Exception:
                pass
        return released_count

    def run(self):
        print(Fore.GREEN + "[START] RAM Monitor Da Bat Dau")
        print(Fore.WHITE + "-" * 50)
        last_ram_release = time.time()

        while True:
            now = time.time()
            current_pids = self.get_roblox_pids()

            new_pids = current_pids - self.tracked
            removed_pids = self.tracked - current_pids

            for pid in new_pids:
                print(Fore.MAGENTA + f"[MONITOR] Phat hien Roblox -> PID {pid}")

            for pid in removed_pids:
                print(Fore.YELLOW + f"[MONITOR] Roblox da tat -> PID {pid}")

            self.tracked = current_pids

            if now - last_ram_release >= self.ram_interval:
                print(Fore.CYAN + "[RAM] Dang thuc hien giai phong RAM...")
                count = self.release_ram()
                print(Fore.GREEN + f"[RAM] Da giai phong RAM cho {count} Roblox")
                last_ram_release = now

            time.sleep(0.5)


def main():
    print_banner()
    try:
        RamMonitorOptimized().run()
    except KeyboardInterrupt:
        print(Fore.CYAN + "\n[EXIT] Thoat tool theo yeu cau nguoi dung")
        print(Fore.YELLOW + f"[INFO] Cam on ban da su dung tool cua {AUTHOR}!")
        print(Fore.YELLOW + f"[INFO] Join Discord: {DISCORD}")
    except Exception as e:
        print(Fore.RED + f"\n[CRITICAL ERROR] Tool gap loi nghiem trong: {e}")

    input(Fore.WHITE + "\nNhan Enter de thoat...")


if __name__ == "__main__":
    main()
