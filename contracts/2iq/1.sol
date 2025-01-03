// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

error PriceMustBeAboveZero();
error AlreadyListed(address collectionAddress, address tokenAddress, uint256 tokenId);
error NotListed(address collectionAddress, address tokenAddress, uint256 tokenId);
error CallerNotAdmin(address caller);
error CallerNotOperator(address caller);
error InvalidAddress(address _address);
error DuplicateListId();
error ListAlreadyExists();
error ListingCannotBeCancelled();
error ListingNotAvailable(bytes32 _listingId);

address constant ZEROADDRESS = address(0x0);

enum ListingState {
    NONE,
    LISTED,
    PAID,
    RELEASED,
    CANCELLED
}

contract StackrListings is AccessControl {
    
    struct Listing {
        bytes32 listingId;
        address collectionAddress;
        address tokenAddress;
        uint256 tokenId;
        address seller;
        address buyer;
        uint256 price;
        address payToken;
        uint256 payTokenPrice;
        
        ListingState state;
        uint256 sellerBurnFeeRate;
        uint256 buyerBurnFeeRate;
    }

    //////////////////////
    //      Events      //
    //////////////////////

    event ItemListed(
        bytes32 listingId,
        address indexed collectionAddress,
        address tokenAddress,
        uint256 tokenId,
        address indexed seller,
        string sellerAuthToken,
        uint256 price,
        address indexed payToken,
        uint256 payTokenPrice,
        string pricingSource
    );
    event ItemBought(bytes32 listingId, address indexed buyer, string buyerAuthToken, uint256 price, address indexed payToken);
    event ItemCanceled(bytes32 listingId, address indexed seller, bool priceReturned);
    event BuyCanceled(bytes32 listingId, address indexed buyer, uint256 amountReturned);
    event ItemReleased(bytes32 listingId, address indexed seller, uint256 price, address payToken);
    event feePaid(bytes32 listingId, address wallet, uint256 fee, address payToken);
    event royaltyFeePaid(bytes32 listingId, address wallet, uint256 fee, address payToken);
    event burnFeePaid(bytes32 listingId, address wallet, uint256 fee, address payToken);
    event SellerBurnRateChanged(uint256 oldRate, uint256 newRate);
    event BuyerBurnRateChanged(uint256 oldRate, uint256 newRate);


    //////////////////////
    //      Variables   //
    //////////////////////

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    address public feeWallet;
    address public burnWallet;

    uint256 public sellerBurnFeeRate;
    uint256 public buyerBurnFeeRate;

    mapping(bytes32 _listingId => Listing) public allListings;
    mapping(bytes32 hash => bytes32) public listingsRegistry;
    
    modifier isListed(bytes32 _listingId) {
        Listing memory listing = allListings[_listingId];
        if (listing.state != ListingState.LISTED && listing.state != ListingState.PAID) {
            revert NotListed(listing.collectionAddress, listing.tokenAddress, listing.tokenId);
        }
        _;
    }

    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert CallerNotAdmin(msg.sender);
        }
        _;
    }

    modifier onlyOperator() {
        if (!hasRole(OPERATOR_ROLE, msg.sender)) {
            revert CallerNotOperator(msg.sender);
        }
        _;
    }

    constructor(
        address _feeWallet,
        address _burnWallet,
        uint256 _sellerBurnFeeRate,
        uint256 _buyerBurnFeeRate
    ) {
        feeWallet = _feeWallet;
        burnWallet = _burnWallet;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        sellerBurnFeeRate = _sellerBurnFeeRate;
        buyerBurnFeeRate = _buyerBurnFeeRate;
    }

    ////////////////////////
    // Action Functions ///
    ///////////////////////

    function listItem(
        bytes32 listingId,
        address collectionAddress,
        address tokenAddress,
        uint256 tokenId,
        address seller,
        string memory sellerAuthToken,
        uint256 price,
        address payToken,
        uint256 payTokenPrice,
        string memory pricingSource
    ) external onlyOperator {
        if (collectionAddress == ZEROADDRESS) revert InvalidAddress(collectionAddress);
        if (tokenAddress == ZEROADDRESS) revert InvalidAddress(tokenAddress);
        if (payToken == ZEROADDRESS) revert InvalidAddress(payToken);

        if (duplicateListId(listingId)) {
          revert DuplicateListId();
        }

        bytes32 listHash = keccak256(abi.encodePacked(collectionAddress, tokenAddress, tokenId));
        if (listingExists(listHash)) {
          revert ListAlreadyExists();
        }

        if (price <= 0) {
            revert PriceMustBeAboveZero();
        }

        allListings[listingId] = Listing(
            listingId,
            collectionAddress,
            tokenAddress,
            tokenId,
            seller,
            ZEROADDRESS,
            price,
            payToken,
            payTokenPrice,
            ListingState.LISTED,
            sellerBurnFeeRate,
            buyerBurnFeeRate
        );

        listingsRegistry[listHash] = listingId;

        emit ItemListed(
            listingId,
            collectionAddress,
            tokenAddress,
            tokenId,
            seller,
            sellerAuthToken,
            price,
            payToken,
            payTokenPrice,
            pricingSource
        );
    }

    function cancelListing(bytes32 _listingId) external onlyOperator isListed(_listingId) {
        Listing memory listedItem = allListings[_listingId];
        if (listedItem.state != ListingState.LISTED && listedItem.state != ListingState.PAID) {
            revert ListingCannotBeCancelled();
        }

        if (listedItem.state == ListingState.PAID) {
            allListings[_listingId].state = ListingState.CANCELLED;
            uint256 buyerBurnFeeAmount = (listedItem.buyerBurnFeeRate * listedItem.price) / 10000;

            require(
                IERC20(listedItem.payToken).transfer(listedItem.buyer, listedItem.price + buyerBurnFeeAmount), 
                "Transfer failed"
            );
        } else {
            allListings[_listingId].state = ListingState.CANCELLED;
        }
        emit ItemCanceled(listedItem.listingId, listedItem.seller, true);
        resetHash(listedItem.collectionAddress, listedItem.tokenAddress, listedItem.tokenId);
    }

    function cancelBuy(bytes32 _listingId) external onlyOperator isListed(_listingId) {
        Listing memory listedItem = allListings[_listingId];
        if(listedItem.state != ListingState.PAID) revert ListingCannotBeCancelled();
        uint256 buyerBurnFeeAmount = (listedItem.buyerBurnFeeRate * listedItem.price) / 10000;
        allListings[_listingId].state = ListingState.LISTED;

        require(
            IERC20(listedItem.payToken).transfer(listedItem.buyer, listedItem.price + buyerBurnFeeAmount),
            "Transfer failed"
        );
        emit BuyCanceled(listedItem.listingId, listedItem.buyer, listedItem.price);
    }

    function buyItem(bytes32 _listingId, string memory buyerAuthToken) external payable isListed(_listingId) {
        Listing memory listedItem = allListings[_listingId];
        if(listedItem.state != ListingState.LISTED) revert ListingNotAvailable(_listingId);

        allListings[_listingId].state = ListingState.PAID;
        allListings[_listingId].buyer = msg.sender;

        uint256 burnFeeAmount = (listedItem.buyerBurnFeeRate * listedItem.price) / 10000;

        require(
            IERC20(listedItem.payToken).transferFrom(msg.sender, address(this), listedItem.price + burnFeeAmount), 
            "Transfer from buyer failed"
        );
        emit ItemBought(listedItem.listingId, msg.sender, buyerAuthToken, listedItem.price, listedItem.payToken);
    }


    function releaseProceeds(
        bytes32 _listingId,
        uint256 feeRate,
        uint256 royaltyFeeRate,
        address royaltyWallet
    ) external onlyOperator {
        Listing memory listedItem = allListings[_listingId];
        require(listedItem.state == ListingState.PAID, "Hasn't been paid or already released");

        allListings[_listingId].state = ListingState.RELEASED;

        uint256 fee = feeRate > 0 ? (listedItem.price * feeRate) / 10000 : 0;
        if (fee > 0) {
            require(IERC20(listedItem.payToken).transfer(feeWallet, fee), "Transfer of fee failed");
            emit feePaid(listedItem.listingId, feeWallet, fee, listedItem.payToken);
        }

        uint256 royaltyFee = royaltyFeeRate > 0 ? (listedItem.price * royaltyFeeRate) / 10000 : 0;
        if (royaltyFee > 0) {
            require(IERC20(listedItem.payToken).transfer(royaltyWallet, royaltyFee), "Transfer of royaltyFee failed");
            emit royaltyFeePaid(listedItem.listingId, royaltyWallet, royaltyFee, listedItem.payToken);
        }

        uint256 selletBurnFee = sellerBurnFeeRate > 0 ? (listedItem.price * sellerBurnFeeRate) / 10000 : 0;
        if (selletBurnFee > 0) {
            require(IERC20(listedItem.payToken).transfer(burnWallet, selletBurnFee), "Transfer of burnFee failed");
            emit burnFeePaid(listedItem.listingId, burnWallet, selletBurnFee, listedItem.payToken);
        }

        uint256 buyerBurnFeeAmount = (listedItem.buyerBurnFeeRate * listedItem.price) / 10000;
        if (buyerBurnFeeAmount > 0) {
            require(
                IERC20(listedItem.payToken).transfer(burnWallet, buyerBurnFeeAmount), 
                "Transfer of burn fee failed"
            );
            emit burnFeePaid(listedItem.listingId, burnWallet, buyerBurnFeeAmount, listedItem.payToken);
        }

        require(
            IERC20(listedItem.payToken).transfer(listedItem.seller, listedItem.price - fee - royaltyFee - selletBurnFee),
            "Transfer to seller failed"
        );
        emit ItemReleased(listedItem.listingId, listedItem.seller, listedItem.price, listedItem.payToken);
        resetHash(listedItem.collectionAddress, listedItem.tokenAddress, listedItem.tokenId);
    }

    function resetHash(
        address collectionAddress,
        address tokenAddress,
        uint256 tokenId
    ) internal {
        bytes32 listHash = keccak256(abi.encodePacked(collectionAddress, tokenAddress, tokenId));
        delete listingsRegistry[listHash];
    }

    /////////////////////
    // Admin Functions //
    /////////////////////

    function changeSellerBurnFee(uint256 _sellerBurnFeeRate) external onlyAdmin {
        uint256 oldRate = sellerBurnFeeRate;
        sellerBurnFeeRate = _sellerBurnFeeRate;
        emit SellerBurnRateChanged(oldRate, _sellerBurnFeeRate);
    }

    function changeBuyerBurnFee(uint256 _buyerBurnFeeRate) external onlyAdmin {
        uint256 oldRate = buyerBurnFeeRate;
        buyerBurnFeeRate = _buyerBurnFeeRate;
        emit BuyerBurnRateChanged(oldRate, _buyerBurnFeeRate);
    }

    function changeFeeWallet(address _feeWallet) external onlyAdmin {
        feeWallet = _feeWallet;
    }

    function changeBurnWallet(address _burnWallet) external onlyAdmin {
        burnWallet = _burnWallet;
    }

    function withdraw() external onlyAdmin {
        payable(msg.sender).transfer(address(this).balance);
    }

    //////////////////////
    // Getter Functions //
    //////////////////////

    function getListingById(bytes32 _listingId) external view returns (Listing memory) {
        return allListings[_listingId];
    }

     function getListingByToken(address collectionAddress, address tokenAddress, uint256 tokenId)
        external
        view
        returns (Listing memory)
    {
        bytes32 hash = keccak256(abi.encodePacked(collectionAddress, tokenAddress, tokenId));
        bytes32 listId = listingsRegistry[hash];
        return allListings[listId];
    }

     function listingExists(bytes32 listHash) public view returns (bool) {
        return listingsRegistry[listHash] != bytes32(0);
    }

    function duplicateListId(bytes32 listingId) public view returns (bool) {
        return allListings[listingId].listingId == listingId;
    }
}