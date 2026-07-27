import os

def delete_temporary_files(directory, temp_file_extensions=None):
    """
    Recursively deletes temporary files in a given directory and its subdirectories.
    
    Parameters:
        directory (str): The path to the directory where temporary files should be deleted.
        temp_file_extensions (list): List of temporary file extensions to look for (e.g., ['.tmp', '.log', '.bak']).
                                      If None, a default set of extensions will be used.
    """
    if temp_file_extensions is None:
        # Default temporary file extensions
        temp_file_extensions = ['.tmp', '.log', '.bak', '.~', '.swp']

    # Walk through the directory
    for root, dirs, files in os.walk(directory):
        for file in files:
            # Check if the file name starts with '~' or if the file extension matches one of the temporary file extensions
            if file.startswith('~') or any(file.endswith(ext) for ext in temp_file_extensions):
                # Construct the full file path
                file_path = os.path.join(root, file)
                try:
                    # Delete the file
                    os.remove(file_path)
                    print(f"Deleted temporary file: {file_path}")
                except Exception as e:
                    print(f"Failed to delete {file_path}: {e}")

# Example usage
if __name__ == "__main__":
    directory_to_clean = "d:/datalib/bra/"
    delete_temporary_files(directory_to_clean)
