# Assuming your folder structure is:
#         $your_parent_folder
#            /        \
#    $we_are_here  blessed-api

# Define source and destination directories
SRC_DIR="./out"
DEST_DIR="../blessed-api/src/lib/contracts/artifacts"

# Copy files
cp "$SRC_DIR/FreeTicket.sol/FreeTicket.json" "$DEST_DIR/tickets.json"
cp "$SRC_DIR/EntranceChecker.sol/EntranceChecker.json" "$DEST_DIR/entrance.json"

echo "Files copied successfully."
