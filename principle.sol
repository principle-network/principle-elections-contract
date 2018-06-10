pragma solidity ^0.4.24;

import "./safemath.sol";
import "./ownable.sol";

contract Principle is Ownable{
    using SafeMath for uint256;
    using SafeMath32 for uint32;
    using SafeMath16 for uint16;

    // Party struct
    struct Party{
        uint id; // party id
        string name;   // short name (up to 32 bytes)
        uint voteCount; // number of accumulated votes
    }

    // List of party names
    string[] public partyList = [
    "LISTA MARJANA SARCA",
    "ZEDINJENA SLOVENIJA",
    "DEMOKRATICNA STRANKA UPOKOJENCEV",
    "DOBRA DRZAVA",
    "SOCIALNI DEMOKRATI",
    "NAPREJ SLOVENIJA",
    "STRANKA MODERNEGA CENTRA",
    "STRANKA ALENKE BRATUSEK",
    "NOVA SLOVENIJA KRSCANSKI DEMOKRATI",
    "SLOVENSKA LJUDSKA STRANKA",
    "SLOVENSKA NACIONALNA STRANKA",
    "SLOVENSKA DEMOKRATSKA STRANKA",
    "ANDREJ CUS IN ZELENI SLOVENIJE",
    "LEVICA",
    "ZDRUZENA LEVICA IN SLOGA",
    "LISTA NOVINARJA BOJANA POZARJA",
    "STRANKA SLOVENSKEGA NARODA",
    "KANGLER & PRIMC ZDRUZENA DESNICA- GLAS ZA OTROKE IN DRUZINE, NOVA LJUDSKA STRANKA SLOVENIJE",
    "PIRATSKA STRANKA SLOVENIJE",
    "ZA ZDRAVO DRUZBO",
    "GOSPODARSKO AKTIVNA STRANKA",
    "SOCIALSTICNA PARTIJA SLOVENIJE",
    "SOLIDARNOST, ZA PRAVICNO DRUZBO",
    "RESIMO SLOVENIJO ELITE IN TAJKUNOV",
    "GIBANJESKUPAJNAPREJ"
    ];

    // Init parties array with parties
    Party[] private parties;

    // Set amount to 0.01 ETH (users will receive this on verification)
    uint amount = 10000000000000000;

    bool public votingInProgress = false;

    // Event that is triggered in user verification process
    event VerifiedAddress(address userAddress, uint valueToSend, bool verified, bool success);
    // Transfer event
    event Transfer(address userAddress, uint value);

    // Is address verified
    mapping(address => bool) public verifiedAddresses;
    // Has address voted
    mapping(address => bool) public votedAddresses;
    // Has token voted
    mapping(bytes32 => bool) public votedTokens;
    // Address to token
    mapping(address => bytes32) public addressToToken;
    // Token to addresses
    mapping(bytes32 => address[]) public tokenToAddresses;

    constructor() public payable {

        // Init parties with the list of parties
        for (uint i = 0; i < partyList.length; i++){
            parties.push(Party({
            id: i,
            name: partyList[i],
            voteCount: 0
            }));
        }
    }

    function stringToBytes32(string memory source) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }

    function addPreviouslyVerifiedAddresses(address[] userAddresses, bytes32[] userTokens) external onlyOwner returns(bool){
        require(userAddresses.length == userTokens.length);

        for(uint i = 0; i < userAddresses.length; i++){
            tokenToAddresses[userTokens[i]].push(userAddresses[i]);
            addressToToken[userAddresses[i]] = userTokens[i];

            if(votedTokens[userTokens[i]]){
                votedAddresses[userAddresses[i]] = true;
                verifiedAddresses[userAddresses[i]] = true;
                continue;
            }

            // Check balance in user wallet
            uint userAddressBalance = userAddresses[i].balance;

            if (amount > userAddressBalance
            && !votedTokens[userTokens[i]]
            && tokenToAddresses[userTokens[i]].length <= 10) {

                // Set amount that has to be sent to user wallet, to be able to execute voting
                uint amountToSend = amount - userAddressBalance;

                if (!userAddresses[i].send(amountToSend)) {

                    // Ether could not be sent to user wallet
                    // Set user address verified to false
                    verifiedAddresses[userAddresses[i]] = true;
                    emit VerifiedAddress(userAddresses[i], amountToSend, verifiedAddresses[userAddresses[i]], false);
                } else {
                    emit Transfer(userAddresses[i], amountToSend);
                }
            }
            // Set user address verified to true
            verifiedAddresses[userAddresses[i]] = true;
            emit VerifiedAddress(userAddresses[i], 0, verifiedAddresses[userAddresses[i]], true);
        }
    }

    function verifyAddress(address userAddress, string userToken) external onlyOwner returns(bool) {
        require(verifiedAddresses[userAddress] == false);

        bytes32 token = stringToBytes32(userToken);
        tokenToAddresses[token].push(userAddress);
        addressToToken[userAddress] = token;

        if(votedTokens[token]){
            votedAddresses[userAddress] = true;
            verifiedAddresses[userAddress] = true;
        }
        // Check balance in user wallet
        uint userAddressBalance = userAddress.balance;

        if (amount > userAddressBalance
        && !votedTokens[token]
        && tokenToAddresses[token].length <= 10) {

            // Set amount that has to be sent to user wallet, to be able to execute voting
            uint amountToSend = amount - userAddressBalance;

            if (!userAddress.send(amountToSend)) {

                // Ether could not be sent to user wallet
                // Set user address verified to false
                verifiedAddresses[userAddress] = true;
                emit VerifiedAddress(userAddress, amountToSend, verifiedAddresses[userAddress], false);
                return false;
            } else {
                emit Transfer(userAddress, amountToSend);
            }
        }

        // Set user address verified to true
        verifiedAddresses[userAddress] = true;
        emit VerifiedAddress(userAddress, 0, verifiedAddresses[userAddress], true);
        return true;
    }

    function getPartiesCount() external view returns (uint) {
        return partyList.length;
    }

    function vote(uint partyIndex) external {
        require(verifiedAddresses[msg.sender] == true
        && votedAddresses[msg.sender] == false
        && partyIndex < partyList.length
        && votingInProgress);

        bytes32 userToken = addressToToken[msg.sender];
        for(uint i = 0; i < tokenToAddresses[userToken].length; i++){
            votedAddresses[tokenToAddresses[userToken][i]] = true;
        }
        votedTokens[userToken] = true;

        parties[partyIndex].voteCount++;
    }

    function getPartyResults(uint partyIndex) public view returns (uint partyId, string name, uint voteCount) {
        require(!votingInProgress);
        partyId = parties[partyIndex].id;
        name = parties[partyIndex].name;
        voteCount = parties[partyIndex].voteCount;
    }

    function getPartyResultsOwner() public view onlyOwner returns (uint[25] partyId, uint[25] voteCount) {

        for(uint i = 0; i<parties.length; i++){
            partyId[i] = parties[i].id;
            voteCount[i] = parties[i].voteCount;
        }
    }

    function toggleVotingStatus() external onlyOwner {
        votingInProgress = !votingInProgress;
    }

    // Kill contract and refund balance to owner
    function kill() external onlyOwner {
        selfdestruct(owner);
    }

}