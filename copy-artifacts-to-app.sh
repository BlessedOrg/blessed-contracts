# Assuming your folder structure is:
#
#           $your_parent_folder
#           /        |         \
# $we_are_here blessed-api  blessed-subgraph

# Define source and destination directories
SRC_DIR="./out"
API_DIR="../blessed-api-new/src/common/lib/contracts/artifacts"
SUBGRAPH_DIR="../blessed-subgraph/0.0.1/abis"

# Copy files to API
cp "$SRC_DIR/Ticket.sol/Ticket.json" "$API_DIR/tickets.json"
cp "$SRC_DIR/USDC.sol/USDC.json" "$API_DIR/erc20.json"
cp "$SRC_DIR/Event.sol/Event.json" "$API_DIR/event.json"
cp "$SRC_DIR/TicketsFactory.sol/TicketsFactory.json" "$API_DIR/tickets-factory.json"

echo "✅ Files copied to API successfully."

# Copy files to Subgraph (run `forge build --extra-output-files abi` to generate ABI-only files as well)
cp "$SRC_DIR/Ticket.sol/Ticket.abi.json" "$SUBGRAPH_DIR/Ticket.json"
#cp "$SRC_DIR/USDC.sol/USDC.abi.json" "$SUBGRAPH_DIR/erc20.json"
#cp "$SRC_DIR/Event.sol/Event.abi.json" "$SUBGRAPH_DIR/event.json"
cp "$SRC_DIR/TicketsFactory.sol/TicketsFactory.abi.json" "$SUBGRAPH_DIR/TicketsFactory.json"

echo "✅ Files copied to Subgraph successfully."
