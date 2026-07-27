import os

def find_files_with_stub(root_path, include_stub, exclude_stub=None, delete_files=False):
    """
    Recursively search for files in all subdirectories that contain a specific stub in their filename.
    Optionally exclude files that contain another stub and delete them if specified.

    Args:
        root_path (str): The root directory to start the search.
        include_stub (str): The filename stub to include in the search.
        exclude_stub (str, optional): The filename stub to exclude from the results.
        delete_files (bool, optional): If True, delete the files found. Defaults to False.
    """
    # Validate inputs
    if not os.path.isdir(root_path):
        print(f"Error: {root_path} is not a valid directory.")
        return

    print(f"Searching for files with stub '{include_stub}' under '{root_path}'...")
    if exclude_stub:
        print(f"Excluding files with stub '{exclude_stub}'.")
    if delete_files:
        print("Warning: Files matching the criteria will be deleted!")

    # Walk through the directory recursively
    for dirpath, _, filenames in os.walk(root_path):
        for file in filenames:
            if include_stub in file and (not exclude_stub or exclude_stub not in file):
                full_path = os.path.join(dirpath, file)
                print(full_path)  # Display file path as it is found
                if delete_files:
                    try:
                        os.remove(full_path)
                        print(f"Deleted: {full_path}")
                    except Exception as e:
                        print(f"Error deleting {full_path}: {e}")

if __name__ == "__main__":
    import argparse
    import sys

    # Check if arguments are provided (for environments like Spyder)
    if len(sys.argv) > 1:
        # Setup argument parser
        parser = argparse.ArgumentParser(description="Search for files with a specific stub in their names.")
        parser.add_argument("root_path", type=str, help="The root directory to start searching.")
        parser.add_argument("include_stub", type=str, help="The filename stub to include in the search.")
        parser.add_argument("--exclude_stub", type=str, default=None, help="The filename stub to exclude (optional).")
        parser.add_argument("--delete", action="store_true", help="Delete files that match the search criteria.")

        # Parse arguments
        args = parser.parse_args()
        find_files_with_stub(args.root_path, args.include_stub, args.exclude_stub, args.delete)
    else:
        # Interactive mode for Spyder: list-only example. NEVER default to deleting.
        print("Running in interactive mode: Using example inputs (list-only).")
        root_path = "Z:/datalib"
        include_stub = "june"
        exclude_stub = "WLD"
        delete_files = False  # deliberately False: pass --delete on the command line to delete
        find_files_with_stub(root_path, include_stub, exclude_stub, delete_files)

# Example usage:
# To search for files containing 'log' in the filename but excluding 'backup' in the '/var/logs' directory:
# find_files_with_stub("/var/logs", "log", "backup")
# This will print all file paths in '/var/logs' and its subdirectories that contain 'log' but do not contain 'backup'.

# Command-line usage example:
# python script_name.py /var/logs log --exclude_stub backup --delete
#
# NOTE: no code runs at import time. An earlier revision called
# find_files_with_stub(..., delete_files=True) at module level, which deleted
# files on Z: the moment this file was imported. Keep ALL calls under
# `if __name__ == "__main__":`.
