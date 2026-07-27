# Script Name: move_folders_files.py
# Date: 2024-12-21
# Author: jpazevedo
# Description: This script copies or moves all files and folders, including subfolders, from a source directory to a destination directory. 
# It supports options to overwrite existing items and toggle between copying and moving. This version uses parallel processing for efficiency.
#
# Functions and Subfunctions:
# 1. process_file:
#    - Handles the copying or moving of individual files.
#    - Parameters:
#      - source_file: Path to the file to be copied/moved.
#      - destination_file: Path where the file will be copied/moved.
#      - overwrite: Boolean flag to overwrite existing files if True.
#      - move: Boolean flag to move files instead of copying if True.
#    - Checks if the destination file exists and acts based on the overwrite flag.
#
# 2. process_directory:
#    - Handles the copying or moving of individual directories.
#    - Parameters:
#      - source_directory: Path to the directory to be copied/moved.
#      - destination_directory: Path where the directory will be copied/moved.
#      - overwrite: Boolean flag to overwrite existing directories if True.
#      - move: Boolean flag to move directories instead of copying if True.
#    - Checks if the destination directory exists and acts based on the overwrite flag.
#
# 3. copy_or_move_files_and_folders:
#    - Orchestrates the entire process of copying or moving files and folders.
#    - Parameters:
#      - source_dir: Root source directory to copy/move from.
#      - destination_dir: Root destination directory to copy/move to.
#      - overwrite: Boolean flag to control overwriting of existing items.
#      - move: Boolean flag to toggle between copying and moving.
#      - max_threads: Maximum number of threads to use for parallel processing.
#    - Uses ThreadPoolExecutor for parallel processing of files and folders.
#    - Iterates over the source directory structure and delegates tasks to process_file and process_directory.
#
# Integration:
# - The main function (copy_or_move_files_and_folders) uses process_file and process_directory as helper functions to perform the actual copying/moving of files and directories.
# - ThreadPoolExecutor enables parallel execution of these tasks to improve performance when handling large directories.

import os
import shutil
from concurrent.futures import ThreadPoolExecutor

def process_file(source_file, destination_file, overwrite, move):
    """
    Copy or move a single file.

    Parameters:
    source_file (str): Path to the source file.
    destination_file (str): Path to the destination file.
    overwrite (bool): If True, overwrite existing items in the destination directory.
    move (bool): If True, move files instead of copying.
    """
    if os.path.exists(destination_file):
        if overwrite:
            os.remove(destination_file)
            print(f"Overwriting file: {destination_file}")
        else:
            print(f"Skipping file: {destination_file}")
            return

    if move:
        shutil.move(source_file, destination_file)
        print(f"Moved file: {source_file} -> {destination_file}")
    else:
        shutil.copy2(source_file, destination_file)
        print(f"Copied file: {source_file} -> {destination_file}")

def process_directory(source_directory, destination_directory, overwrite, move):
    """
    Copy or move a single directory.

    Parameters:
    source_directory (str): Path to the source directory.
    destination_directory (str): Path to the destination directory.
    overwrite (bool): If True, overwrite existing items in the destination directory.
    move (bool): If True, move directories instead of copying.
    """
    if os.path.exists(destination_directory):
        if overwrite:
            shutil.rmtree(destination_directory)
            print(f"Overwriting folder: {destination_directory}")
        else:
            print(f"Skipping folder: {destination_directory}")
            return

    if move:
        shutil.move(source_directory, destination_directory)
        print(f"Moved folder: {source_directory} -> {destination_directory}")
    else:
        shutil.copytree(source_directory, destination_directory)
        print(f"Copied folder: {source_directory} -> {destination_directory}")

def copy_or_move_files_and_folders(source_dir, destination_dir, overwrite=False, move=False, max_threads=4):
    """
    Copy or move all files and folders, including subfolders, from the source directory to the destination directory.

    Parameters:
    source_dir (str): Path to the source directory.
    destination_dir (str): Path to the destination directory.
    overwrite (bool): If True, overwrite existing items in the destination directory. Default is False.
    move (bool): If True, move files and folders instead of copying. Default is False.
    max_threads (int): Maximum number of threads to use for parallel processing. Default is 4.
    """
    try:
        # Ensure source directory exists
        if not os.path.exists(source_dir):
            print(f"Source directory '{source_dir}' does not exist.")
            return

        # Ensure destination directory exists
        if not os.path.exists(destination_dir):
            os.makedirs(destination_dir)

        tasks = []

        # Walk through all directories and files in the source directory
        with ThreadPoolExecutor(max_threads) as executor:
            for root, dirs, files in os.walk(source_dir, topdown=True):
                # Construct relative path
                relative_path = os.path.relpath(root, source_dir)
                current_destination = os.path.join(destination_dir, relative_path)

                # Ensure the current destination path exists
                if not os.path.exists(current_destination):
                    os.makedirs(current_destination)

                # Process files
                for file in files:
                    source_file = os.path.join(root, file)
                    destination_file = os.path.join(current_destination, file)
                    tasks.append(executor.submit(process_file, source_file, destination_file, overwrite, move))

                # Process directories
                for directory in dirs:
                    source_directory = os.path.join(root, directory)
                    destination_directory = os.path.join(current_destination, directory)
                    tasks.append(executor.submit(process_directory, source_directory, destination_directory, overwrite, move))

            # Wait for all tasks to complete
            for task in tasks:
                task.result()

        print("All files and folders have been processed successfully.")

    except Exception as e:
        print(f"An error occurred: {e}")




# Example usage
if __name__ == "__main__":
    # Placeholders. Point these at your own trees; a real internal path here
    # would both mislead anyone else running the script and disclose the
    # organisation of a tree they cannot see.
    source_directory = "D:/my-source-tree"
    destination_directory = "Z:/my-destination-tree"
    overwrite_option = False  # Set to False to skip existing items
    move_option = False  # Set to True to move files and folders instead of copying
    max_threads_option = 4  # Maximum number of threads to use
    copy_or_move_files_and_folders(source_directory, destination_directory, overwrite=overwrite_option, move=move_option, max_threads=max_threads_option)
