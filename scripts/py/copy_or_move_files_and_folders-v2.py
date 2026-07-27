# Script Name: move_folders_files.py
# Date: 2024-12-21
# Author: jpazevedo
# Description: This script copies or moves all files and folders, including subfolders, from a source directory to a destination directory. 
# It supports options to overwrite existing items, compare files between source and destination, and toggle between copying and moving. This version uses parallel processing for efficiency and generates a markdown report.
# Additionally, it provides an option to only generate a report without performing any file operations, and the path for saving the report can be specified.

# Functions and Subfunctions:
# 1. compare_files:
#    - Compares files between the source and destination directories.
#    - Parameters:
#      - source_file: Path to the file in the source directory.
#      - destination_file: Path to the file in the destination directory.
#      - report: Dictionary to record comparison results.
#    - Records files not in the destination, files newer in the source, and files that are the same.
#
# 2. generate_report:
#    - Generates a markdown report summarizing file and folder operations and comparisons.
#    - Parameters:
#      - report: Dictionary containing actions performed and comparison results.
#      - output_file: Path to the markdown report file.
#    - Outputs the report in a structured table format, documenting file sizes in MB.
#
# 3. process_file:
#    - Handles the copying or moving of individual files.
#    - Parameters:
#      - source_file: Path to the file to be copied/moved.
#      - destination_file: Path where the file will be copied/moved.
#      - overwrite: Boolean flag to overwrite existing files if True.
#      - move: Boolean flag to move files instead of copying.
#      - report: Dictionary to record actions for the markdown report.
#    - Checks if the destination file exists and acts based on the overwrite flag.
#
# 4. copy_or_move_files_and_folders:
#    - Orchestrates the entire process of copying or moving files and folders, or generating a comparison report.
#    - Parameters:
#      - source_dir: Root source directory to copy/move from.
#      - destination_dir: Root destination directory to copy/move to.
#      - overwrite: Boolean flag to control overwriting of existing items.
#      - move: Boolean flag to toggle between copying and moving.
#      - max_threads: Maximum number of threads to use for parallel processing.
#      - report_only: Boolean flag to only generate a comparison report without performing file operations.
#      - report_file: Path to the markdown report file.
#    - Uses ThreadPoolExecutor for parallel processing of files and folders.
#    - Iterates over the source directory structure, compares files, and delegates tasks to process_file.

import os
import shutil
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime


def compare_files(source_file, destination_file, report):
    """
    Compare files between source and destination directories.

    Parameters:
    source_file (str): Path to the file in the source directory.
    destination_file (str): Path to the file in the destination directory.
    report (dict): Dictionary to record comparison results.
    """
    source_file = os.path.normpath(source_file)
    destination_file = os.path.normpath(destination_file)

    if not os.path.exists(source_file):
        return  # Optionally log or skip this file

    if not os.path.exists(destination_file):
        report['not_in_destination'].append(source_file)
        return

    source_mtime = os.path.getmtime(source_file)
    destination_mtime = os.path.getmtime(destination_file)
    source_size = os.path.getsize(source_file) / (1024 * 1024)
    destination_size = os.path.getsize(destination_file) / (1024 * 1024)

    if source_mtime > destination_mtime:
        report['newer_in_source'].append({
            'source_file': source_file,
            'destination_file': destination_file,
            'source_size': source_size,
            'source_date': source_mtime,
            'destination_size': destination_size,
            'destination_date': destination_mtime
        })
    else:
        report['same_files'].append(source_file)



def generate_report(report, output_file):
    """
    Generate a markdown report summarizing the file and folder operations and comparisons.

    Parameters:
    report (dict): Dictionary containing actions performed and comparison results.
    output_file (str): Path to the markdown report file.
    """
    with open(output_file, 'w') as f:
        # Write the report header
        f.write("# File and Folder Comparison Report\n\n")

        # Iterate over report categories
        for category, items in report.items():
            if not items:
                continue  # Skip empty categories

            # Handle simple categories (single-column table)
            if category in ['not_in_destination', 'same_files']:
                f.write(f"## {category.replace('_', ' ').capitalize()}\n\n")
                f.write("| File Path |\n")
                f.write("| --- |\n")
                for item in items:
                    escaped_item = item.replace("|", "\\|")  # Escape pipes in file paths
                    f.write("| {} |\n".format(escaped_item))
                f.write("\n")

            # Handle complex categories (multi-column table)
            elif category == 'newer_in_source':
                f.write(f"## {category.replace('_', ' ').capitalize()}\n\n")
                f.write("| Source File | Source Size (MB) | Source Date | Destination File | Destination Size (MB) | Destination Date |\n")
                f.write("| --- | --- | --- | --- | --- | --- |\n")
                for item in items:
                    try:
                        # Format timestamps into readable dates
                        source_date = datetime.fromtimestamp(item['source_date']).strftime('%Y-%m-%d %H:%M:%S')
                        destination_date = datetime.fromtimestamp(item['destination_date']).strftime('%Y-%m-%d %H:%M:%S')
                        
                        # Escape pipes in file paths
                        source_file = item['source_file'].replace("|", "\\|")
                        destination_file = item['destination_file'].replace("|", "\\|")
                        
                        # Write the formatted row
                        f.write("| {} | {:.2f} | {} | {} | {:.2f} | {} |\n".format(
                            source_file,
                            item['source_size'],
                            source_date,
                            destination_file,
                            item['destination_size'],
                            destination_date
                        ))
                    except Exception as e:
                        # Log or handle errors gracefully
                        f.write(f"| Error processing item: {e} |\n")
                f.write("\n")
                
                

def process_file(source_file, destination_file, overwrite, move, report):
    """
    Copy or move a single file.

    Parameters:
    source_file (str): Path to the source file.
    destination_file (str): Path to the destination file.
    overwrite (bool): If True, overwrite existing items in the destination directory.
    move (bool): If True, move files instead of copying.
    report (dict): Dictionary to record actions for the markdown report.
    """
    if os.path.exists(destination_file):
        if overwrite:
            os.remove(destination_file)
            report['overwritten_files'].append(destination_file)
        else:
            report['skipped_files'].append(destination_file)
            return

    if move:
        shutil.move(source_file, destination_file)
        report['moved_files'].append(destination_file)
    else:
        shutil.copy2(source_file, destination_file)
        report['copied_files'].append(destination_file)

def copy_or_move_files_and_folders(source_dir, destination_dir, overwrite=False, move=False, max_threads=4, report_only=False, report_file="operation_report.md"):
    """
    Copy or move all files and folders, or only generate a comparison report based on the `report_only` flag.

    Parameters:
    source_dir (str): Path to the source directory.
    destination_dir (str): Path to the destination directory.
    overwrite (bool): If True, overwrite existing items in the destination directory. Default is False.
    move (bool): If True, move files and folders instead of copying. Default is False.
    max_threads (int): Maximum number of threads to use for parallel processing. Default is 4.
    report_only (bool): If True, only generate a comparison report without performing file operations. Default is False.
    report_file (str): Path to the markdown report file. Default is "operation_report.md".
    """
    try:
        # Ensure source directory exists
        if not os.path.exists(source_dir):
            print(f"Source directory '{source_dir}' does not exist.")
            return

        # Ensure destination directory exists
        if not os.path.exists(destination_dir):
            os.makedirs(destination_dir)

        report = {
            'copied_files': [],
            'moved_files': [],
            'skipped_files': [],
            'overwritten_files': [], 
            'not_in_destination': [],
            'newer_in_source': [],
            'same_files': []
        }

        tasks = []

        # Walk through all directories and files in the source directory
        with ThreadPoolExecutor(max_threads) as executor:
            for root, dirs, files in os.walk(source_dir, topdown=True):
                # Construct relative path
                relative_path = os.path.relpath(root, source_dir)
                current_destination = os.path.join(destination_dir, relative_path)

                # Compare files
                for file in files:
                    source_file = os.path.join(root, file)
                    destination_file = os.path.join(current_destination, file)
                    compare_files(source_file, destination_file, report)

                    if not report_only:
                        tasks.append(executor.submit(process_file, source_file, destination_file, overwrite, move, report))

            # Wait for all tasks to complete if performing operations
            if not report_only:
                for task in tasks:
                    task.result()

        # Generate the markdown report
        generate_report(report, report_file)

        if report_only:
            print("Comparison report generated successfully.")
        else:
            print("File operations completed and report generated successfully.")

    except Exception as e:
        print(f"An error occurred: {e}")

# Example usage
if __name__ == "__main__":
    # Placeholders -- see the note in copy_or_move_files_and_folders.py.
    source_directory = "D:/my-source-tree"
    destination_directory = "Z:/my-destination-tree"
    overwrite_option = False  # Set to True to overwrite existing files and folders
    move_option = False  # Set to True to move files and folders instead of copying
    max_threads_option = 4  # Maximum number of threads to use
    report_only_option = True  # Set to True to only generate the comparison report
    report_file_option = "./operation_report.md"  # Path to the report file

    copy_or_move_files_and_folders(
        source_directory,
        destination_directory,
        overwrite=overwrite_option,
        move=move_option,
        max_threads=max_threads_option,
        report_only=report_only_option,
        report_file=report_file_option
    )
