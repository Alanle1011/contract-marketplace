1. Create a decentralized NFT marketplace
   1. `listItem`: List NFTs on the marketplace
   2. `buyItem`: Buy the NFTs
   3. `cacelItem`: Cancel a listing
   4. `updateListing`: Update price
   5. `widthrawProceeds`: Withdraw payment for my bought NFTs
   6. `listBiddingItem`: List the bidding item
   7. `raiseBidPrice`: Reaise the price ò the bidding nft
   8. `cancelBidding`: Owner can cacel the bid item
   9. `buyBidItem`: After bidding time, hightest bidder can buy the nft


```shell
yarn 
yarn install
```
To deploy the contract
```
yarn hardhat deploy
```
To Mint and list nft to the marketplce
```
yarn hardhat run scripts/mint-and-list.js --network localhost
```
