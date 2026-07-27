import os
import shutil

def delete_subfolders_with_word(root_folder, word, override_warning=False):
    # Walk through the directory tree
    for root, dirs, files in os.walk(root_folder, topdown=False):
        for dir_name in dirs:
            # Check if the specific word is in the directory name (case insensitive)
            if word.lower() in dir_name.lower():
                # Full path of the subfolder
                full_path = os.path.join(root, dir_name)
                
                # If override_warning is False, show warning and ask for confirmation
                if not override_warning:
                    print(f"WARNING: The folder '{full_path}' contains the word '{word}' and will be deleted.")
                    print("All files and subdirectories within this folder will be permanently deleted.")
                    confirmation = input("Do you want to proceed with deletion? (yes/no): ").strip().lower()
                    
                    if confirmation != 'yes':
                        print(f"Skipping deletion of: {full_path}")
                        continue  # Skip to the next directory
                
                # Proceed with deletion
                try:
                    shutil.rmtree(full_path)
                    print(f"Deleted: {full_path}")
                except Exception as e:
                    print(f"Failed to delete {full_path}: {e}")

# Example usage:
# To delete with confirmation:
# delete_subfolders_with_word('D:/datalib/CCC', 'PANEL')

# To delete without confirmation:
# delete_subfolders_with_word('D:/datalib/CCC', 'PANEL', override_warning=True)
