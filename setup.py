from pathlib import Path
import os
import re
import sys
from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parent
ENV_FILE = PROJECT_ROOT / ".env"


def load_db_path() -> str:
    if not ENV_FILE.exists():
        sys.exit("Error: .env not found. Create it first (see README Step 4).")

    load_dotenv(ENV_FILE)
    db_path = os.getenv("DB_PATH")

    if not db_path or not db_path.strip():
        sys.exit("Error: DB_PATH not found or empty in .env.")

    return db_path.strip()


def ensure_absolute(path_value: str) -> str:
    if not Path(path_value).is_absolute():
        sys.exit("Error: DB_PATH must be an absolute path in .env (see README Step 4).")
    return path_value


def set_windows_user_env(name: str, value: str) -> None:
    import winreg

    with winreg.OpenKey(
        winreg.HKEY_CURRENT_USER, r"Environment", 0, winreg.KEY_SET_VALUE
    ) as key:
        winreg.SetValueEx(key, name, 0, winreg.REG_EXPAND_SZ, value)


def pick_shell_profile() -> Path:
    home = Path.home()
    shell = os.environ.get("SHELL", "")
    if (home / ".zshrc").exists() or "zsh" in shell:
        return home / ".zshrc"
    if (home / ".bashrc").exists():
        return home / ".bashrc"
    return home / ".profile"


def update_shell_profile(profile: Path, db_path: str) -> None:
    export_line = f'export DB_PATH="{db_path}"'
    lines = profile.read_text(encoding="utf-8").splitlines() if profile.exists() else []
    lines = [line for line in lines if not re.match(r"^\s*export DB_PATH=", line)]
    lines.append(export_line)
    profile.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    db_path = ensure_absolute(load_db_path())
    os.environ["DB_PATH"] = db_path

    if sys.platform == "win32":
        set_windows_user_env("DB_PATH", db_path)
        print("DB_PATH set permanently for your user account:")
    else:
        profile = pick_shell_profile()
        update_shell_profile(profile, db_path)
        print(f"DB_PATH set permanently in {profile}:")

    print(f"  {db_path}\n")
    print("Close and reopen your terminal, then run: dbt debug")


if __name__ == "__main__":
    main()