import os
import zipfile

def unzip_files_in_folder(root_folder):
    """
    Recursively go through all subfolders in a folder and unzip all .zip files.

    Parameters:
    root_folder (str): The path to the root folder where the search for .zip files should start.

    Returns:
    None
    """
    for foldername, subfolders, filenames in os.walk(root_folder):
        # Skip the "Data" subfolder
        if "Data" in subfolders:
            subfolders.remove("Data")
        
        for filename in filenames:
            if filename.lower().endswith('.zip'):
                file_path = os.path.join(foldername, filename)
                extract_to = foldername  # Extract files to the same folder where the zip file is located

                try:
                    with zipfile.ZipFile(file_path, 'r') as zip_ref:
                        # Extract all contents of the zip file into the same folder
                        for member in zip_ref.namelist():
                            # Determine the target path for the extracted file
                            target_path = os.path.join(extract_to, os.path.basename(member))
                            # Check if the file already exists
                            if os.path.exists(target_path):
                                print(f"File already exists, skipping: {target_path}")
                                continue
                            # Extract the file if it does not exist
                            with zip_ref.open(member) as source, open(target_path, 'wb') as target:
                                target.write(source.read())
                        print(f"Successfully extracted: {file_path}")
                    
                    # Delete the zip file after extraction
                    os.remove(file_path)
                    print(f"Deleted zip file: {file_path}")
                
                except zipfile.BadZipFile:
                    print(f"Error: {file_path} is not a valid zip file.")
                except Exception as e:
                    print(f"An error occurred while extracting {file_path}: {e}")

if __name__ == "__main__":
    root_folder = "d:/datalib/BRA"
    unzip_files_in_folder(root_folder)