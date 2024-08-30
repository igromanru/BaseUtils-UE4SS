import os
import shutil
import fnmatch

ITEMS_TO_REMOVE = ['.git*', '*.gitignore', '*.gitattributes', '*.gitmodules', '*.md', '*.md', '*.json', 'AFUtilsDebug.lua', 'nexusmods']

def remove_specified_files(directory):
    for root, dirs, files in os.walk(directory, topdown=False):
        for pattern in ITEMS_TO_REMOVE:
            # Check both files and directories
            for item in dirs + files:
                if fnmatch.fnmatch(item, pattern):
                    item_path = os.path.join(root, item)
                    remove_item(item_path)

        # Remove empty directories
        try:
            if not os.listdir(root):
                os.rmdir(root)
                print(f"Removed empty directory: {root}")
        except OSError as e:
            print(f"Error removing empty directory {root}: {e}")

def remove_item(path):
    if os.path.isfile(path):
        try:
            os.remove(path)
            print(f"Removed file: {path}")
        except OSError as e:
            print(f"Error removing file {path}: {e}")
    elif os.path.isdir(path):
        try:
            shutil.rmtree(path,)
            print(f"Removed directory: {path}")
        except OSError as e:
            print(f"Error removing directory {path}: {e}")

if __name__ == "__main__":
    current_directory = os.getcwd()
    print(f"Starting cleanup in: {current_directory}")
    print(f"Items to be removed: {ITEMS_TO_REMOVE}")
    remove_specified_files(current_directory)
    print("Cleanup completed.")