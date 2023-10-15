// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";

contract LuckyFT is
	ERC1155,
	ERC1155Burnable,
	ERC1155Supply,
	VRFV2WrapperConsumerBase,
	ConfirmedOwner
{
	using Math for uint256;

	constructor(
		address initialOwner
	)
		ERC1155("LuckyFT")
		ConfirmedOwner(msg.sender)
		VRFV2WrapperConsumerBase(linkAddress, wrapperAddress)
	{}

	uint256 currentTokenId = 1;
	uint256 price = 0.0001 ether;
	mapping(uint256 => address) tokenOwnerMap; // id => address
	mapping(address => uint256) tokenIdMap; // address => id
	mapping(uint256 => mapping(address => bool)) tokenMinterMap;
	mapping(uint256 => address[]) tokenMinterArr;
	mapping(address => uint256) userBalance;
	mapping(uint256 => uint256) tokenBalance;
	mapping(uint256 => uint256[]) requestIdMap;

	function setURI(string memory newuri) public onlyOwner {
		_setURI(newuri);
	}

	function updatePrice(uint256 _price) public onlyOwner {
		price = _price;
	}

	function createFT() public payable {
		address createdBy = _msgSender();
		require(msg.value >= price, "payment not enough");
		require(tokenIdMap[createdBy] == 0, "you already have LuckyFT");

		tokenOwnerMap[currentTokenId] = createdBy;
		tokenIdMap[createdBy] = currentTokenId;
		currentTokenId = currentTokenId + 1;
	}

	function buy(uint256 id) public payable {
		address createdBy = _msgSender();
		require(msg.value >= price, "Not enough payment");
		require(
			tokenIdMap[createdBy] != 0,
			"you need to create a LuckyFT first"
		);
		require(!tokenMinterMap[id][createdBy], "You already mint this FT");

		tokenMinterMap[id][createdBy] = true;
		tokenMinterArr[id].push(createdBy);
		_mint(createdBy, id, 1, "0x0");

		uint256 requestId = requestRandomWords();
		requestIdMap[requestId] = [id, price];
	}

	function getOwnerById(uint256 tokenId) public view returns (address) {
		return tokenOwnerMap[tokenId];
	}

	function getUserBlance(address account) public view returns (uint256) {
		return userBalance[account];
	}

	function claimUserBalance() public {
		address payable to = payable(_msgSender());
		uint256 value = userBalance[to];
		require(value > 0, "user do not have balance");
		userBalance[to] = 0;
		(bool success, ) = to.call{ value: value }("");
		require(success, "claim failed");
	}

	// function mintBatch(
	// 	address to,
	// 	uint256[] memory ids,
	// 	uint256[] memory amounts,
	// 	bytes memory data
	// ) public onlyOwner {
	// 	_mintBatch(to, ids, amounts, data);
	// }

	// The following functions are overrides required by Solidity.
	function _update(
		address from,
		address to,
		uint256[] memory ids,
		uint256[] memory values
	) internal override(ERC1155, ERC1155Supply) {
		super._update(from, to, ids, values);
	}

	// chainlink VRF
	event RequestSent(uint256 requestId, uint32 numWords);
	event RequestFulfilled(
		uint256 requestId,
		uint256[] randomWords,
		uint256 payment
	);

	struct RequestStatus {
		uint256 paid; // amount paid in link
		bool fulfilled; // whether the request has been successfully fulfilled
		uint256[] randomWords;
	}
	mapping(uint256 => RequestStatus)
		public s_requests; /* requestId --> requestStatus */

	// past requests Id.
	uint256[] public requestIds;
	uint256 public lastRequestId;

	// Depends on the number of requested values that you want sent to the
	// fulfillRandomWords() function. Test and adjust
	// this limit based on the network that you select, the size of the request,
	// and the processing of the callback request in the fulfillRandomWords()
	// function.
	uint32 callbackGasLimit = 100000;

	// The default is 3, but you can set this higher.
	uint16 requestConfirmations = 3;

	// For this example, retrieve 2 random values in one request.
	// Cannot exceed VRFV2Wrapper.getConfig().maxNumWords.
	uint32 numWords = 2;

	// Address LINK - hardcoded for Sepolia
	address linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

	// address WRAPPER - hardcoded for Sepolia
	address wrapperAddress = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;

	function requestRandomWords() internal returns (uint256 requestId) {
		requestId = requestRandomness(
			callbackGasLimit,
			requestConfirmations,
			numWords
		);
		s_requests[requestId] = RequestStatus({
			paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
			randomWords: new uint256[](0),
			fulfilled: false
		});
		requestIds.push(requestId);
		lastRequestId = requestId;
		emit RequestSent(requestId, numWords);
		return requestId;
	}

	function fulfillRandomWords(
		uint256 _requestId,
		uint256[] memory _randomWords
	) internal override {
		require(s_requests[_requestId].paid > 0, "request not found");
		s_requests[_requestId].fulfilled = true;
		s_requests[_requestId].randomWords = _randomWords;
		emit RequestFulfilled(
			_requestId,
			_randomWords,
			s_requests[_requestId].paid
		);

		uint256[] memory params = requestIdMap[_requestId];
		uint256 id = params[0];
		uint256 rewardVal = params[1] / 10;

		uint256 totalSupply = super.totalSupply(id);
		uint256 rewardInFTIndex = _randomWords[0] % totalSupply;
		// some random minter in current room
		userBalance[tokenMinterArr[id][rewardInFTIndex]] += rewardVal;

		uint256 rewardRoomInGlobalIndex = ((_randomWords[1] %
			(currentTokenId - 1)) + 1);
		// some random room owner
		userBalance[tokenOwnerMap[rewardRoomInGlobalIndex]] += rewardVal;

		// random room's random minter
		uint256 globalRoomSupply = super.totalSupply(rewardRoomInGlobalIndex);
		uint256 rewardFTInGlobalRoomIndex = _randomWords[1] % globalRoomSupply;
		userBalance[
			tokenMinterArr[rewardRoomInGlobalIndex][rewardFTInGlobalRoomIndex]
		] += rewardVal;

		// uint256[] memory params1 = [
		// 	id,
		// 	price,
		// 	rewardInFTIndex,
		// 	rewardRoomInGlobalIndex,
		// 	rewardFTInGlobalRoomIndex
		// ];
		// address[] calldata params2 = [
		// 	tokenMinterArr[id][rewardInFTIndex],
		// 	tokenOwnerMap[rewardRoomInGlobalIndex],
		// 	tokenMinterArr[rewardRoomInGlobalIndex][rewardFTInGlobalRoomIndex]
		// ];

		// emit RewardLucky(params1, params2);
	}

	event RewardLucky(
		// id, price
		uint256[5] params1,
		// inFTAddress, globalRoomOwnerAddress, globalRoomFTAddress
		address[3] params2
	);

	function getRequestStatus(
		uint256 _requestId
	)
		external
		view
		returns (uint256 paid, bool fulfilled, uint256[] memory randomWords)
	{
		require(s_requests[_requestId].paid > 0, "request not found");
		RequestStatus memory request = s_requests[_requestId];
		return (request.paid, request.fulfilled, request.randomWords);
	}

	/**
	 * Allow withdraw of Link tokens from the contract
	 */
	function withdrawLink() public onlyOwner {
		LinkTokenInterface link = LinkTokenInterface(linkAddress);
		require(
			link.transfer(msg.sender, link.balanceOf(address(this))),
			"Unable to transfer"
		);
	}

	function withdrawAllEthAndLinkForTest() public onlyOwner {
		address payable to = payable(_msgSender());
		uint256 value = address(this).balance;
		(bool success, ) = to.call{ value: value }("");
		require(success, "withdraw failed");

		LinkTokenInterface link = LinkTokenInterface(linkAddress);
		require(
			link.transfer(msg.sender, link.balanceOf(address(this))),
			"Unable to transfer"
		);
	}
}
