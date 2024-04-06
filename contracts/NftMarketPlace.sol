// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error NftMarketPlace__PriceMustBeAboveZero();
error NftMarketPlace__NotApproveForMarketPlace();
error NftMarketPlace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketPlace__NotListed(address nftAddress, uint256 tokenId);
error NftMarketPlace__NotNftOwner();
error NftMarketPlace__PriceNotMet(
  address nftAddress,
  uint256 tokenId,
  uint256 price
);
error NftMarketPlace__BiddingTimeIsOver();
error NftMarketPlace__BuyBiddingTimeIsNotMeet(
  address nftAddress, 
  uint256 tokenId, 
  uint256 startBuyTime,
  uint256 endBuyTime
);
error NftMarketPlace__NotTheHighestBidder();
error NftMarketPlace__NotBidding();
error NftMarketPlace__NoProceeds();
error NftMarketPlace__TransferFailed();
error NftMarketPlace__FeesTransferFailed();

contract NftMarketPlace is ReentrancyGuard {
  struct Listing {
    uint256 price;
    address seller;
  }
  struct Bidding {
    address seller;
    address buyer;
    uint256 price;
    uint256 startBuyTime;
    uint256 endBuyTime;
  }

  event ItemListed(
    address indexed seller,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 price
  );
  event BidItemListed(
    address indexed seller,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 price
  );
  event ItemBought(
    address indexed buyer,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 price
  );
  event RaiseBidPrice(
    address indexed buyer,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 startBuyTime,
    uint256 endBuyTime,
    uint256 price
  );
  event ItemCanceled(
    address indexed seller,
    address indexed nftAddress,
    uint256 tokenId
  );
  event BidItemBought(
    address indexed buyyer,
    address indexed nftAddress, 
    uint256 tokenId, uint256 price
  );
  
  address public owner;
  uint256 public withdrawFees;

  // NFT COntract address -> NFT TokenIID -> listing
  mapping(address => mapping(uint256 => Listing)) s_listings;

  // // NFT address -> NFT TokenIID -> Bidding
  mapping(address => mapping(uint256 => Bidding)) s_biddings;

  //Seller address -> amount earned
  mapping(address => uint256) private s_proceeds;

  //////////////////
  // Construtors  //
  //////////////////
  constructor(uint256 _withdrawFees) {
    owner = msg.sender;
    withdrawFees = _withdrawFees;
  }

  //////////////////
  // Modifiers    //
  //////////////////
  modifier notListed(
    address nftAddress,
    uint256 tokenId,
    address nftOwner
  ) {
    Listing memory listing = s_listings[nftAddress][tokenId];

    if (listing.price > 0) {
      revert NftMarketPlace__AlreadyListed(nftAddress, tokenId);
    }
    _;
  }
  modifier isListed(address nftAddress, uint256 tokenId) {
    Listing memory listing = s_listings[nftAddress][tokenId];
    if (listing.price <= 0) {
      revert NftMarketPlace__NotListed(nftAddress, tokenId);
    }
    _;
  }
  modifier isBidding(address nftAddress, uint256 tokenId) {
    Bidding memory bidding = s_biddings[nftAddress][tokenId];
    if (bidding.seller == address(0)) {
      revert NftMarketPlace__NotBidding();
    }
    _;
  }
  modifier isNftOwner(
    address nftAddress,
    uint256 tokenId,
    address spender
  ) {
    IERC721 nft = IERC721(nftAddress);
    address nftOwner = nft.ownerOf(tokenId);
    if (spender != nftOwner) {
      revert NftMarketPlace__NotNftOwner();
    }
    _;
  }

  //////////////////
  // Main function//
  //////////////////

  /**
   * @notice Method for listing your NFT on the marketplace
   * @param nftAddress: Address of th NFT
   * @param tokenId : The TokenID of the NFT
   * @param price : sale price of the listed NFT
   * @dev Tecnically, we could have the contract be the escrow for the NFTs but this way people can still hold their NFTs when listed.
   */
  function listItem(
    address nftAddress,
    uint256 tokenId,
    uint256 price
  )
    external
    notListed(nftAddress, tokenId, msg.sender)
    isNftOwner(nftAddress, tokenId, msg.sender)
  {
    if (price <= 0) {
      revert NftMarketPlace__PriceMustBeAboveZero();
    }
    IERC721 nft = IERC721(nftAddress);
    if (nft.getApproved(tokenId) != address(this)) {
      revert NftMarketPlace__NotApproveForMarketPlace();
    }
    s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
    emit ItemListed(msg.sender, nftAddress, tokenId, price);
  }

  function buyItem(
    address nftAddress,
    uint256 tokenId
  ) external payable nonReentrant isListed(nftAddress, tokenId) {
    Listing memory listedItem = s_listings[nftAddress][tokenId];
    if (msg.value < listedItem.price) {
      revert NftMarketPlace__PriceNotMet(nftAddress, tokenId, listedItem.price);
    }
    s_proceeds[listedItem.seller] = s_proceeds[listedItem.seller] + msg.value;

    delete (s_listings[nftAddress][tokenId]);
    IERC721(nftAddress).safeTransferFrom(
      listedItem.seller,
      msg.sender,
      tokenId
    );
    emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
  }

  function cancelListing(
    address nftAddress,
    uint256 tokenId
  )
    external
    isNftOwner(nftAddress, tokenId, msg.sender)
    isListed(nftAddress, tokenId)
  {
    delete (s_listings[nftAddress][tokenId]);
    emit ItemCanceled(msg.sender, nftAddress, tokenId);
  }

  function updateListing(
    address nftAddress,
    uint256 tokenId,
    uint256 newPrice
  )
    external
    isNftOwner(nftAddress, tokenId, msg.sender)
    isListed(nftAddress, tokenId)
  {
    if (newPrice <= 0) {
      revert NftMarketPlace__PriceMustBeAboveZero();
    }
    s_listings[nftAddress][tokenId].price = newPrice;

    emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
  }

  function withdrawProceeds() external payable nonReentrant {
    uint256 proceeds = s_proceeds[msg.sender];
    if (proceeds <= 0) {
      revert NftMarketPlace__NoProceeds();
    }
    s_proceeds[msg.sender] = 0;

    uint256 feesAmount = proceeds * withdrawFees / 100;
    uint256 withdrawAmount = proceeds - feesAmount;

    // Send fees to the Owner
    (bool feeSucces, ) = payable(owner).call{ value: feesAmount }("");
    if (!feeSucces) {
      revert NftMarketPlace__FeesTransferFailed();
    }

    // Send money to the User
    (bool success, ) = payable(msg.sender).call{ value: withdrawAmount }("");
    if (!success) {
      revert NftMarketPlace__TransferFailed();
    }
  }

  function listBiddingItem(
    address nftAddress,
    uint256 tokenId,
    uint256 price
  ) external isNftOwner(nftAddress, tokenId, msg.sender) {
    IERC721 nft = IERC721(nftAddress);
    if (nft.getApproved(tokenId) != address(this)) {
      revert NftMarketPlace__NotApproveForMarketPlace();
    }
    
    s_biddings[nftAddress][tokenId] = Bidding(msg.sender, 0x0000000000000000000000000000000000000000, price, 0, 0);
    emit BidItemListed(msg.sender, nftAddress, tokenId, price);
  }

  function raiseBidPrice(
    address nftAddress,
    uint256 tokenId,
    uint256 price
  )external payable nonReentrant isBidding(nftAddress, tokenId) {
    Bidding memory biddingItem = s_biddings[nftAddress][tokenId];
    if (price <= biddingItem.price) {
      revert NftMarketPlace__PriceNotMet(nftAddress, tokenId, biddingItem.price);
    }
    if(biddingItem.startBuyTime != 0) {
      if(block.timestamp > biddingItem.startBuyTime &&block.timestamp < biddingItem.endBuyTime ){
        revert NftMarketPlace__BiddingTimeIsOver();
      }
    }
    
    uint256 newStartTime = block.timestamp + 300; // Add 5' the current time
    uint256 newEndTime = newStartTime + 300; // Add 10' the current time
    s_biddings[nftAddress][tokenId] = Bidding(biddingItem.seller, msg.sender, price, newStartTime, newEndTime);
    emit RaiseBidPrice(msg.sender,nftAddress, tokenId, newStartTime, newEndTime, price);
  }

  function cancelBidding(
    address nftAddress,
    uint256 tokenId
  )
    external
    isNftOwner(nftAddress, tokenId, msg.sender)
    isBidding(nftAddress, tokenId)
  {
    delete (s_biddings[nftAddress][tokenId]);
    emit ItemCanceled(msg.sender, nftAddress, tokenId);
  }

  function buyBidItem(
    address nftAddress,
    uint256 tokenId
  ) external payable nonReentrant isBidding(nftAddress, tokenId) {
    Bidding memory biddingItem = s_biddings[nftAddress][tokenId];
    if(block.timestamp > biddingItem.endBuyTime || block.timestamp < biddingItem.startBuyTime ){
      revert NftMarketPlace__BuyBiddingTimeIsNotMeet(nftAddress, tokenId, biddingItem.startBuyTime ,biddingItem.endBuyTime);
    }

    if(biddingItem.buyer != msg.sender){
      revert NftMarketPlace__NotTheHighestBidder();
    }

    if (msg.value < biddingItem.price) {
      revert NftMarketPlace__PriceNotMet(nftAddress, tokenId, biddingItem.price);
    }

    s_proceeds[biddingItem.seller] = s_proceeds[biddingItem.seller] + msg.value;
    delete (s_biddings[nftAddress][tokenId]);
    IERC721(nftAddress).safeTransferFrom(
      biddingItem.seller,
      msg.sender,
      tokenId
    );
    emit BidItemBought(msg.sender, nftAddress, tokenId, biddingItem.price);
  }
  /////////////////////
  // Getter function //
  /////////////////////

  function getListing(
    address nftAddress,
    uint256 tokenId
  ) external view returns (Listing memory) {
    return s_listings[nftAddress][tokenId];
  }

  function getBidding(
    address nftAddress,
    uint256 tokenId
  ) external view returns (Bidding memory) {
    return s_biddings[nftAddress][tokenId];
  }

  function getProceeds(address seller) external view returns (uint256) {
    return s_proceeds[seller];
  }
}

//    1. `listItem`: List NFTs on the marketplace
//    2. `buyItem`: Buy the NFTs
//    3. `cacelItem`: Cancel a listing
//    4. `updateListing`: Update price
//    5. `widthrawProceeds`: Withdraw payment for my bought NFTs
//    6. `listBiddingItem`: List the bidding item
//    7. `raiseBidPrice`: Reaise the price ò the bidding nft
//    8. `cancelBidding`: Owner can cacel the bid item
//    9. `buyBidItem`: After bidding time, hightest bidder can buy the nft