// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "./vendor/Base.sol";
import "./vendor/Library.sol";
import "./vendor/ReclaimBase.sol";

error InsufficientBalance(uint256 required, uint256 available);
error InvalidSupply(uint256 requested, uint256 maximum);
error ZeroAddress();
error InvalidFeePercentage(uint256 fee);
error StakeholdersAreLocked();
error TokenIdOverflow();
error TransfersNotAllowed();
error NotWhitelisted(address user);
error ExceedsMaxSupply(uint256 requested, uint256 maximum);
error EmptyDistributions();
error StakeholderAlreadyExists(address wallet);
error ArrayLengthMismatch();
error InvalidStakeholderIndex(uint256 index, uint256 length);

contract Ticket is 
    ReentrancyGuard,
    Base,
    ReclaimBase,
    ERC1155,
    ERC1155Burnable,
    ERC1155Supply,
    IERC1155Receiver 
{
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for uint256;
    using SafeERC20 for IERC20;

    address public immutable eventAddress;
    address public immutable erc20Address;
    IERC20 public immutable erc20Token;
    uint256 public immutable initialSupply;
    uint256 public immutable maxSupply;
    uint256 public currentSupply;
    uint256 public nextTokenId = 1;
    uint256 public price = 0;
    string public symbol;
    mapping(address => EnumerableSet.UintSet) private userTokens;
    EnumerableSet.AddressSet private ticketHolders;
    mapping(address => bool) public isWhitelisted;
    bool public transferable;
    bool public whitelistOnly;

    struct Distribution {
        address recipient;
        uint96 amount;
    }
    uint256 public distributionsCounter;

    struct Whitelist {
        address user;
        bool status;
    }

    Library.Stakeholder[] public stakeholders;
    uint256 public totalFeePercentage;
    bool public stakeholdersLocked;
    uint256 public stakeholdersCounter;

    event SupplyUpdated(uint256 newSupply);
    event StakeholderAdded(address wallet, uint256 feePercentage);
    event StakeholderUpdated(address wallet, uint256 feePercentage);
    event StakeholderRemoved(address wallet);
    event StakeholdersLocked();
    event MintedFromProof(uint256 timestamp, address userSmartWalletAddress, string context, string userSmartWalletAddressFromContext);
    event TicketPurchased(uint256 price, uint256 stakeholdersShare);
    event URIUpdated(string newUri);
    event PriceUpdated(uint256 newPrice);
    event WhitelistStatusUpdated(bool status);
    event TokenMinted(address indexed to, uint256 tokenId);
    event BatchMinted(address indexed to, uint256 amount, uint256 firstTokenId);
    event TransferableStatusUpdated(bool status);
    event WhitelistUpdated(address indexed user, bool status);
    
    constructor(Library.TicketConstructor memory config)
    Base(config._owner, config._ownerSmartWallet, config._name)
    ERC1155(config._baseURI) {
        if (config._initialSupply > config._maxSupply) revert ExceedsMaxSupply(config._initialSupply, config._maxSupply);
        ownerSmartWallet = config._ownerSmartWallet;
        name = config._name;
        symbol = config._symbol;
        eventAddress = config._eventAddress;
        erc20Address = config._erc20Address;
        erc20Token = IERC20(config._erc20Address);
        price = config._price;
        initialSupply = config._initialSupply;
        maxSupply = config._maxSupply;
        currentSupply = config._initialSupply;
        transferable = config._transferable;
        whitelistOnly = config._whitelistOnly;

        uint256 stakeholdersLength = config._stakeholders.length;
        for (uint256 i; i < stakeholdersLength;) {
            _addStakeholder(
                config._stakeholders[i].wallet,
                config._stakeholders[i].feePercentage
            );
            unchecked { ++i; }
        }
        stakeholdersCounter = config._stakeholders.length;
    }

    function setURI(string calldata newuri) external onlyOwner {
        _setURI(newuri);
        emit URIUpdated(newuri);
    }

    function updateSupply(uint256 _additionalSupply) external onlyOwner {
        if (currentSupply + _additionalSupply > maxSupply) revert ExceedsMaxSupply(currentSupply + _additionalSupply, maxSupply);
        uint256 newSupply = currentSupply + _additionalSupply;
        currentSupply = newSupply;
        emit SupplyUpdated(newSupply);
    }

    function updateWhitelist(Whitelist[] calldata _whitelistUpdates) external onlyOwner {
        uint256 length = _whitelistUpdates.length;
        for (uint256 i; i < length;) {
            Whitelist memory update = _whitelistUpdates[i];
            isWhitelisted[update.user] = update.status;
            emit WhitelistUpdated(update.user, update.status);
            unchecked { ++i; }
        }
    }

    function setTransferable(bool _transferable) external onlyOwner {
        transferable = _transferable;
        emit TransferableStatusUpdated(_transferable);
    }

    function get() external nonReentrant {
        if (!stakeholdersLocked && nextTokenId > 1) {
            stakeholdersLocked = true;
            emit StakeholdersLocked();
        }
        _checkWhitelist(msg.sender);
        _checkSupply(1);
        
        if (price > 0) {
            if (erc20Token.balanceOf(msg.sender) < price) revert InsufficientBalance(price, erc20Token.balanceOf(msg.sender));
            if (erc20Token.allowance(msg.sender, address(this)) < price) revert InsufficientBalance(price, erc20Token.allowance(msg.sender, address(this)));
        }

        uint256 tokenId = nextTokenId;
        if (nextTokenId >= type(uint256).max) revert TokenIdOverflow();
        unchecked { ++nextTokenId; }
        _mint(msg.sender, tokenId, 1, "");

        if (price > 0) {
            uint256 currentPrice = price;
            erc20Token.safeTransferFrom(msg.sender, address(this), currentPrice);

            uint256 remainingAmount = currentPrice;
            Library.Stakeholder[] memory _stakeholders = stakeholders;
            uint256 stakeholdersLength = _stakeholders.length;
            
            for (uint256 i; i < stakeholdersLength;) {
                uint256 stakeholderFee = (currentPrice * _stakeholders[i].feePercentage) / 10000;
                if (stakeholderFee > 0) {
                    erc20Token.safeTransfer(_stakeholders[i].wallet, stakeholderFee);
                    remainingAmount -= stakeholderFee;
                }
                unchecked { ++i; }
            }

            if (remainingAmount > 0) {
                erc20Token.safeTransfer(ownerSmartWallet, remainingAmount);
            }
            
            emit TicketPurchased(price, price - remainingAmount);
        }
    }

    function verifyProofAndMint(Proof calldata proof) external {
        try IReclaimVerifier(0xF90085f5Fd1a3bEb8678623409b3811eCeC5f6A5).verifyProof(proof) {
            string memory context = proof.claimInfo.context;
            string memory userSmartWalletAddressString = extractFieldFromContext(context, '"userSmartWalletAddress":"');
            address userSmartWalletAddress = stringToAddress(userSmartWalletAddressString);
            _checkWhitelist(userSmartWalletAddress);
            _checkSupply(1);
            mint(userSmartWalletAddress);
            emit MintedFromProof(block.timestamp, userSmartWalletAddress, context, userSmartWalletAddressString);
        } catch {
            revert("Proof verification failed");
        }
    }

    function distribute(Distribution[] calldata _distributions) external onlyOwner {
        uint256 length = _distributions.length;
        if (length == 0) revert EmptyDistributions();

        uint256 amountToBeDistributed;
        for (uint256 i; i < length;) {
            Distribution calldata dist = _distributions[i];
            if (dist.recipient == address(0)) revert ZeroAddress();
            if (dist.amount == 0) revert InvalidSupply(dist.amount, 0);
            _checkWhitelist(dist.recipient);
            amountToBeDistributed += dist.amount;
            unchecked { ++i; }
        }
        
        _checkSupply(amountToBeDistributed);

        for (uint256 i; i < length;) {
            Distribution calldata dist = _distributions[i];
            _mintSequential(dist.recipient, dist.amount);
            unchecked { ++i; }
        }
        currentSupply -= amountToBeDistributed;
        unchecked { ++distributionsCounter; }

        emit SupplyUpdated(currentSupply);
    }

    function addStakeholder(address payable _wallet, uint256 _feePercentage) external onlyOwner {
        if (stakeholdersLocked) revert StakeholdersAreLocked();
        _addStakeholder(_wallet, _feePercentage);
    }

    function updateStakeholder(uint256 _index, uint256 _feePercentage) external onlyOwner {
        if (stakeholdersLocked) revert StakeholdersAreLocked();
        if (_index >= stakeholders.length) revert InvalidStakeholderIndex(_index, stakeholders.length);
        if (_feePercentage <= 0 || _feePercentage > 10000) revert InvalidFeePercentage(_feePercentage);

        Library.Stakeholder memory stakeholder = stakeholders[_index];
        uint256 oldFeePercentage = stakeholder.feePercentage;
        if (totalFeePercentage - oldFeePercentage + _feePercentage > 10000) revert InvalidFeePercentage(totalFeePercentage - oldFeePercentage + _feePercentage);

        stakeholders[_index].feePercentage = _feePercentage;
        totalFeePercentage = totalFeePercentage - oldFeePercentage + _feePercentage;
        emit StakeholderUpdated(stakeholders[_index].wallet, _feePercentage);
    }

    function removeStakeholder(uint256 _index) external onlyOwner {
        if (stakeholdersLocked) revert StakeholdersAreLocked();
        if (_index >= stakeholders.length) revert InvalidStakeholderIndex(_index, stakeholders.length);

        totalFeePercentage -= stakeholders[_index].feePercentage;
        emit StakeholderRemoved(stakeholders[_index].wallet);

        stakeholders[_index] = stakeholders[stakeholders.length - 1];
        stakeholders.pop();
    }

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert InvalidSupply(tokenId, 0);
        return string(abi.encodePacked(super.uri(tokenId), tokenId.toString()));
    }

    function getTicketHolders(uint256 start, uint256 pageSize) public view returns (address[] memory) {
        uint256 totalHolders = ticketHolders.length();
        uint256 end = start + pageSize;
        if (end > totalHolders) {
            end = totalHolders;
        }

        address[] memory holders = new address[](end - start);
        for (uint256 i = start; i < end;) {
            holders[i - start] = ticketHolders.at(i);
            unchecked { ++i; }
        }

        return holders;
    }
    
    function getTokensByUser(address user) public view returns (uint256[] memory) {
        return userTokens[user].values();
    }

    function userHasToken(address user, uint256 tokenId) public view returns (bool) {
        return userTokens[user].contains(tokenId);
    }

    function mint(address recipient) internal {
        if (!stakeholdersLocked && nextTokenId > 1) {
            stakeholdersLocked = true;
            emit StakeholdersLocked();
        }
        _mint(recipient, nextTokenId, 1, "");
        emit TokenMinted(recipient, nextTokenId);
        if (nextTokenId >= type(uint256).max) revert TokenIdOverflow();
        unchecked { ++nextTokenId; }
    }

    function _mintSequential(address recipient, uint256 amount) internal {
        uint256 firstTokenId = nextTokenId;
        for (uint256 i; i < amount;) {
            mint(recipient);
            unchecked { ++i; }
        }
        emit BatchMinted(recipient, amount, firstTokenId);
    }

    function _addStakeholder(address payable _wallet, uint256 _feePercentage) internal {
        if (_feePercentage <= 0 || _feePercentage > 10000) revert InvalidFeePercentage(_feePercentage);
        
        uint256 newTotalFee = totalFeePercentage + _feePercentage;
        if (newTotalFee > 10000) revert InvalidFeePercentage(newTotalFee);
        totalFeePercentage = newTotalFee;

        uint256 stakeholdersLength = stakeholders.length;
        for (uint256 i; i < stakeholdersLength;) {
            if (stakeholders[i].wallet == _wallet) revert StakeholderAlreadyExists(_wallet);
            unchecked { ++i; }
        }

        stakeholders.push(Library.Stakeholder(_wallet, _feePercentage));
        emit StakeholderAdded(_wallet, _feePercentage);
    }

    function _checkWhitelist(address recipient) internal view {
        if (whitelistOnly) {
            if (!isWhitelisted[recipient]) revert NotWhitelisted(recipient);
        }
    }

    function _checkSupply(uint256 amount) internal view {
        if (currentSupply < amount) revert InvalidSupply(amount, currentSupply);
        if (currentSupply + amount > maxSupply) revert ExceedsMaxSupply(currentSupply + amount, maxSupply);
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);

        uint256 idsLength = ids.length;  // Cache length
        for (uint256 i; i < idsLength;) {
            if (values[i] > 0) {
                if (from != address(0)) {
                    uint256 fromBalance = balanceOf(from, ids[i]);  // Cache balance
                    if (fromBalance == 0) {
                        userTokens[from].remove(ids[i]);
                        if (userTokens[from].length() == 0) {
                            ticketHolders.remove(from);
                        }
                    }
                }
                if (to != address(0)) {
                    userTokens[to].add(ids[i]);
                    ticketHolders.add(to);
                }
            }
            unchecked { ++i; }
        }

        if (from == address(0) || to == address(0)) {
            return;
        }

        if (!transferable) {
            revert TransfersNotAllowed();
        }

        if (whitelistOnly) {
            if (!isWhitelisted[_msgSender()]) revert NotWhitelisted(_msgSender());
            if (!isWhitelisted[to]) revert NotWhitelisted(to);
        }
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return totalSupply(tokenId) > 0;
    }

    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC1155, IERC165) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}