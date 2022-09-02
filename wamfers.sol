//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import 'https://raw.githubusercontent.com/w1nt3r-eth/hot-chain-svg/main/contracts/SVG.sol';
//import 'https://raw.githubusercontent.com/w1nt3r-eth/hot-chain-svg/main/contracts/Utils.sol';
//import 'https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/master/contracts/utils/Strings.sol';
import 'https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.7.2/contracts/utils/Base64.sol';
//import 'https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.7.2/contracts/token/ERC721/ERC721.sol';
import 'https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.7.2/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import 'https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.7.2/contracts/finance/PaymentSplitter.sol';

contract OnChainMfer is ERC721Enumerable, PaymentSplitter {
    string constant ipfsGateway = 'https://ipfs.io/ipfs/';
    string constant ipfsHash = 'QmPe4dQyZfuyQuxYnoYxo3QSFnQzegHDVAohMxqvNvR3GF';
    string constant imageExtension = '.png';

    struct Trait {
      string kind;
      string value;
    }

    // tokenId to traits
    mapping(uint256 => Trait[]) TokenTraits;

    // keccak256 to tokenId
    mapping(bytes32 => uint256) TokenIdFromHash;

    // tokenId to keccak256
    mapping(uint256 => bytes32) HashFromTokenId;


    constructor(address[] memory _payees, uint256[] memory _shares) 
        ERC721('onchain mfer', 'OCMFER') 
        PaymentSplitter(_payees, _shares) payable {
    }

    function mint(Trait[] memory traits) public payable {        
     require(traits.length <= 14, 'Too many traits');
     require(msg.value >= (0.0420 ether), 'Ether value sent is not correct');

     // start w/ token id 1
     uint256 tokenId = totalSupply() + 1;

     //require(HashFromTokenId[tokenId] == 0, 'Token id already exists');

     bytes5[] memory arr = new bytes5[](traits.length);
     string memory s = '';
     for(uint i = 0; i < traits.length;  i++) {
          Trait memory trait = traits[i];
          s = string(abi.encodePacked(s, trait.kind, trait.value));
          for (uint j = 0; j < i; j++) {
            require(arr[j] != bytes5(bytes(trait.kind)), 'Trait kind used multiple times');
          }
          arr[i] = bytes5(bytes(trait.kind));
          TokenTraits[tokenId].push(trait);
     }
     bytes32 tokenHash = keccak256(abi.encodePacked(s));
     
     // need token id to start at 1 not 0
     require(TokenIdFromHash[tokenHash] == 0, 'Traits already exist');

     TokenIdFromHash[tokenHash] = tokenId;
     HashFromTokenId[tokenId] = tokenHash;
     _safeMint(msg.sender, tokenId);
    }

    function getTokenTraits(uint256 tokenId) public view returns (Trait[] memory) {
       return TokenTraits[tokenId];
    }

    function getTokenIdByHash(bytes32 tokenHash) public view returns (uint256) {
       return TokenIdFromHash[tokenHash];
    }

    function getHashByTokenId(uint256 hashToken) public view returns (bytes32) {
       return HashFromTokenId[hashToken];
    }

    function renderToken(uint256 tokenId) public view returns (string memory) {
       return render(getHashByTokenId(tokenId), getTokenTraits(tokenId));
    }

    function traitImageUri(string memory traitType, string memory trait) private pure returns (string memory) {
      return string.concat(ipfsGateway, ipfsHash, '/', traitType, '/', trait, imageExtension);
    }

    function layer(string memory traitType, string memory trait) private pure returns (string memory) {
      return string.concat('<image href="', traitImageUri(traitType, trait), '" height="1000" width="1000" />');
    }

    function hashText(bytes32 tokenHash) private pure returns (string memory) {
      return string.concat(svg.text(
                string.concat(
                    svg.prop('x', '1000'),
                    svg.prop('y', '8'),
                    svg.prop('font-size', '8'),
                    svg.prop('fill', 'white'),
                    svg.prop('stroke', 'black'),
                    svg.prop('stroke-width', '0.5'),
                    svg.prop('transform', 'scale (-1, 1)'),
                    svg.prop('transform-origin', 'center'),
                    svg.prop('text-anchor', 'end')
                ),
                Strings.toHexString(uint256(tokenHash), 32)
            ));
    }

    string constant svgHeader = '<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="1000"'
                                'viewBox="0 0 1000 1000" transform="scale (-1, 1)" transform-origin="center"'
                                'style="width:auto;height:auto;max-width:100%;max-height:100%;">';

    function render(bytes32 tokenHash, Trait[] memory traits) public pure returns (string memory) {
        string memory s = svgHeader;
        for(uint i = 0; i < traits.length;  i++) {
            Trait memory trait = traits[i];
            s = string(abi.encodePacked(s, layer(trait.kind, trait.value)));
        }
        s = string(abi.encodePacked(s, hashText(tokenHash), '</svg>'));
        return s;
    }

    function attribute(Trait memory trait) private pure returns (string memory) {
      return string.concat('{"trait_type":"', trait.kind, '","value":"', trait.value, '"}');
    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {
      bytes32 tokenHash = getHashByTokenId(tokenId);
      Trait[] memory traits = getTokenTraits(tokenId);

      string memory metadata = string.concat('{"name":"onchain mfer #', Strings.toString(tokenId), '","attributes":[');
      string memory svgImage = svgHeader;

      for(uint i = 0; i < traits.length;  i++) {
        Trait memory trait = traits[i];
        svgImage = string(abi.encodePacked(svgImage, layer(trait.kind, trait.value)));
        metadata = string(abi.encodePacked(metadata, attribute(trait)));
        if (i != traits.length - 1) {
            metadata = string.concat(metadata, ',');
        }
      }

      svgImage = string(abi.encodePacked(svgImage, hashText(tokenHash), '</svg>'));
      metadata = string(abi.encodePacked(metadata, 
        '],"animation_url":"data:text/html;base64,',
        Base64.encode(bytes(string.concat('<!DOCTYPE html><html><body>', svgImage, '</body></html>'))),
        //'","image_data":"data:svg+xml;base64,', Base64.encode(bytes(svgImage)),
        '"}'));
    
      return string.concat('data:application/json;base64,', Base64.encode(bytes(metadata)));
    }
}