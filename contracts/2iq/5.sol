// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import"@openzeppelin/contracts/token/ERC721/ERC721.sol";
import"@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import"@openzeppelin/contracts/utils/Counters.sol";


contract SchoolNft is ERC721URIStorage{
  using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;


    
    address payable owner;
    uint listingPrice= 1.5 ether;

    uint256 royaltyFeesInBips;
    address royaltyAddress;
    
    struct MarketItem {
        uint256 tokenId;
        string schoolname;
        address payable owner;
        address payable seller;
        uint256 price;
        string desc;
        bool sold;
    }

      uint256 itemId;

      mapping(uint256=>MarketItem)public idToMarketItem;
       
      mapping(address => bool) public alreadyMinted;    

      constructor()ERC721 ("DEVELOPERSTUDIO TOKEN","DSTT") {
          owner=payable(msg.sender);
          royaltyAddress = owner;
         
    }
     function mintToken(string memory tokenURI
     )public payable returns(uint256){
         require(msg.value>0,"Minting price must at least 1 wei");
         require(alreadyMinted[msg.sender] == false, "Address already used");
         _tokenIds.increment();
         uint256 newTokenId=_tokenIds.current();
         _mint(msg.sender,newTokenId);
         _setTokenURI(newTokenId,tokenURI);
         alreadyMinted[msg.sender] = true;
          return newTokenId;

     }

   function createMarketItem( 
    uint256 tokenId,
    uint256 price,
    string memory schoolname,
    string memory desc
  ) public payable  {
    
    require(price > 0, "Price must be at least 1 wei");
    require(msg.value == listingPrice, "Price must be equal to listing price");
        msg.value-listingPrice;
     itemId+=1;
    idToMarketItem[itemId] =  MarketItem(
      tokenId,
      schoolname,
       payable(msg.sender),
       payable(owner),
      price,desc,false
    );
          _transfer(msg.sender,address(this), tokenId);

   }

      function updateListingPrice(uint _listingPrice) public  {
      require(owner == msg.sender, "Only marketplace owner can update listing price.");
      listingPrice = _listingPrice;
    }

   function getListingPrice() public view returns (uint256) {
      return listingPrice;
    }

      function fetchMarketItems() public view returns (MarketItem[] memory) {
      uint  ItemCount = itemId;
      uint currentIndex = 0;


      MarketItem[] memory items = new MarketItem[](itemId);
      for (uint i = 0; i < ItemCount; i++) {

          uint currentId = i + 1;
          MarketItem storage currentItem = idToMarketItem[currentId];
          items[currentIndex] = currentItem;
          currentIndex += 1;
        
      }
      return items;
    }



     function Buy(uint256 tokenId)external payable { 
       
       uint price = idToMarketItem[tokenId].price;
      address seller = idToMarketItem[tokenId].seller;
      require(msg.value == price, "Please submit the asking price in order to complete the purchase");
      require(msg.sender!= seller,"You can't buy");
         msg.value-price;
      idToMarketItem[tokenId].owner = payable(msg.sender);
      idToMarketItem[tokenId].sold = true;
      idToMarketItem[tokenId].seller = payable(owner);
      _itemsSold.increment();
      _transfer(address(this), msg.sender, tokenId);


      payable(owner).transfer(listingPrice);
      payable(seller).transfer(msg.value);

         
}


    function setRoyaltyInfo(address _receiver, uint256 _royaltyFeesInBips) public    {
       
        require(owner==msg.sender,"only owner can set");
        royaltyAddress = _receiver;
        royaltyFeesInBips = _royaltyFeesInBips;
    }
       function royaltyInfo(uint256 _tokenId)external view virtual
   
        returns (address, uint256)
    {
        
        return (royaltyAddress, calculateRoyalty(_tokenId));
    }

     function calculateRoyalty(uint256 tokenId) view public returns (uint256) {
       uint256 _salePrice = idToMarketItem[tokenId].price;
        return (_salePrice / 100) * royaltyFeesInBips;
    }

  

       function resellToken(uint256 tokenId, uint256 price) public payable{
          require(idToMarketItem[tokenId].owner==msg.sender,"Only the item owner can perform this operation");
          require(msg.value>=listingPrice,"price must be  equal to listing price");
          idToMarketItem[tokenId].sold=true;
         idToMarketItem[tokenId].price=price;
         idToMarketItem[tokenId].seller=payable(msg.sender);
         idToMarketItem[tokenId].owner=payable(address(this));
         _itemsSold.decrement();

          _transfer(msg.sender,address(this),tokenId);
  }
}
