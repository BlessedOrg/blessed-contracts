# Define source and destination directories
SRC_DIR="./out"
DEST_DIR="../blessed-api/src/lib/contracts/artifacts"

# Copy files
cp "$SRC_DIR/FreeTicket.sol/FreeTicket.json" "$DEST_DIR/tickets.json"

echo "Files copied successfully."
