import os
import zipfile

def zip_subfolders_in_year_folders(root_dir):
    # Ensure the root directory exists
    if not os.path.exists(root_dir):
        print(f"The directory {root_dir} does not exist.")
        return
    
    # Iterate through each item in the root directory
    for year_folder in os.listdir(root_dir):
        year_folder_path = os.path.join(root_dir, year_folder)
        
        # Check if the item is a directory and if its name is a year (4 digits)
        if os.path.isdir(year_folder_path) and year_folder.isdigit() and len(year_folder) == 4:
            # Iterate through each subfolder inside the year folder
            for subfolder in os.listdir(year_folder_path):
                subfolder_path = os.path.join(year_folder_path, subfolder)
                
                # Check if the item is a directory (subfolder)
                if os.path.isdir(subfolder_path):
                    zip_filename = os.path.join(year_folder_path, f"{subfolder}.zip")
                    
                    # Create a zip file with the same name as the subfolder
                    with zipfile.ZipFile(zip_filename, 'w', zipfile.ZIP_DEFLATED) as zipf:
                        # Walk through the subfolder directory
                        for root, dirs, files in os.walk(subfolder_path):
                            for file in files:
                                file_path = os.path.join(root, file)
                                # Add file to the zip file, maintaining directory structure
                                arcname = os.path.relpath(file_path, start=subfolder_path)
                                zipf.write(file_path, arcname=arcname)
                    
                    print(f"Zipped {subfolder} to {zip_filename}")

# Example usage:
root_dir = "C:/data/example_folder"
zip_subfolders_in_year_folders(root_dir)
