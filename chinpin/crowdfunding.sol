// Done by Alexander J. Lee
// aljilee@ucsc.edu

pragma solidity ^0.4.24;

  /** @dev Import functions from the token contract. */
contract Token {
    function mintTokens (uint256, uint256, string) public pure {}
    function _transfer (address, address, uint256) private pure returns (bool) {}
    function transfer (address , uint256) public pure {}
    function transferFrom (address, address, uint256) public pure {}
    function allowance (address, address) public pure {}
    function tokenInfo () public pure returns (uint256, uint256, string, address) {}
}

/** @title Create and execute a crowdsale. */
contract Crowdsale {
     
    /** @dev Events for token contract */
    event eventCreated (address indexed _creator, uint256 _eventID);
    event eventStarted (uint256 indexed _eventID);
    event investmentSent (address _investor, uint256 _eventID);
    event eventFinished (uint256 _eventID);
    
    /** @dev This is an unique event ID that each crowdsale event has that allows us to differentiate between different events. */ 
    uint256 eventID;
    
    /** @dev Struct of an event.
      * @param creator            The creator of the event
      * @param storeKeys          Stores the keys of all investors for an event
      * @param amountRaised       The current amount raised in an event
      * @param fundingGoal        The funding goal for an event
      * @param eventStart         When an event will start
      * @param eventEnd           When an event will end
      * @param eventDuration      How long an event will last
      * @param eventID            The unique eventID of an event
      * @param description        A brief description of an event
      * @param eventLive          Tells us whether the event is currently live
      * @param eventDuration      How much longer an event will last
      * @param continueAfterGoal  If an event will continue to accept investments if it                                   exceeds the goal 
      * @param mintTokens         Tells us whether we have minted tokens for the event
      * @param distributeTokens   Tells us whether the event will distribute asset tokens
      * @param refundEther        Tells us whether the event will refund ether
      */
    struct Event {
        address creator;
        address[] storeKeys;
        address tokenAddress;
        
        uint256 amountRaised;
        uint256 fundingGoal;
        uint256 eventStart;
        uint256 eventEnd;
        uint256 eventDuration;
        uint256 eventID;
        
        string description;
        
        bool eventLive;
        bool fundingGoalReached;
        bool continueAfterGoal;
        bool mintTokens;
        bool distributeTokens;
        bool refundEther;
    }
    
    /** @dev This is the struct that stores an investor's data for all events. We will create an array of struct for each investor in which each investment that an investor makes is represented by one index of an InvestorData struct. 
      * @param investorKey            The investor's address
      * @param amountContributed      The amount that they invested
      * @param timeOfContribution     The time of the investment
      * @param timeOfRefund           The time of the refund
      * @param bool refunded          Whether they have been refunded or not
      */
    struct InvestorData {
        address investorKey;
        uint256 amountContributed;
        uint256 timeOfContribution; 
        uint256 timeOfRefund;
        uint256 timeOfTokenWithdrawal;
        bool refunded;
        bool recieveToken;
    }    
    
    /** @dev Maps an eventID to an event. */
    mapping(uint256 => Event) eventMap;
    
    /** @dev Maps an eventID to a mapping of an investor's key to that investor's data. */
    mapping(uint256 => mapping(address => InvestorData[])) investorMap;
    
    /** Maps an eventID to a mapping of an investor's key to the amount of ether to send. */
    mapping(uint256 => mapping(address => uint256)) balance;
    
    /** Mapping to allow one token per event */
    mapping(uint256 => address) eventToken;
    
    /** @dev This function is made for creating and initializing an event. The eventID of the event ID is generated by incrementing the eventID counter by 1 (starts at 0). 
      * @param _fundingGoal        The fundraising goal of the event in ether
      * @param _eventDuration      How long the event will last (in minutes)
      * @param _description        A brief description of the event
      * @param _continueAfterGoal  Continue accepting ether after surpassing funding goal 
      */
    function createEvent (uint256 _fundingGoal, uint256 _eventDuration, string _description, bool _continueAfterGoal) public {
        Event memory myEvent;
        myEvent.creator = msg.sender;
        myEvent.fundingGoal = _fundingGoal;
        myEvent.eventDuration = _eventDuration * 60;
        eventID += 1;
        myEvent.eventID = eventID;
        myEvent.description = _description;
        myEvent.continueAfterGoal = _continueAfterGoal;
        myEvent.eventLive = false;
        eventMap[myEvent.eventID] = myEvent;
        emit eventCreated(myEvent.creator, myEvent.eventID);
    }
    
    /** @dev This function is made for starting an event. It does not allow you to restart an event that has ended.
      * @param _eventID The eventID of the event you want to start.
      */
    function startEvent (uint256 _eventID) public {
        require(msg.sender == eventMap[_eventID].creator);
        require(eventMap[_eventID].eventEnd == 0);
        eventMap[_eventID].eventStart = now;
        eventMap[_eventID].eventEnd = now + eventMap[_eventID].eventDuration;
        eventMap[_eventID].eventLive = true;
        emit eventStarted(_eventID);
    }
    
    /** @dev This function is made for ending an event.
      * @param _eventID The eventID of the event that ends.
      */
    function endEvent (uint256 _eventID) private {
        eventMap[_eventID].eventEnd = now;
        eventMap[_eventID].eventLive = false;
        if (eventMap[_eventID].amountRaised >= eventMap[_eventID].fundingGoal) {
            eventMap[_eventID].fundingGoalReached = true;
            eventMap[_eventID].distributeTokens = true;
            eventMap[_eventID].mintTokens = true;
        } else {
            eventMap[_eventID].refundEther = true;
        }
        emit eventFinished(_eventID);
    }
    
    /** @dev This function is made for manually terminating an event.
      * @param _eventID  The eventID of the event to terminate.
      */
      function terminateEvent (uint256 _eventID) public {
        require (msg.sender == eventMap[_eventID].creator);
        endEvent(_eventID);
      }
      
    /** @dev This function is for returning basic event information. */
    function eventData(uint256 _eventID) public view returns (uint256 numEvents, address eventCreator, string _eventDescription, uint256 _eventStart, uint256 _eventEnd, uint256 _currentTime, bool _continueAfterReachingGoal) {
        return (eventID, eventMap[_eventID].creator, eventMap[_eventID].description,   eventMap[_eventID].eventStart, eventMap[_eventID].eventEnd, now, eventMap[_eventID].continueAfterGoal);
    }
    
    /** This function is for returning event information pertaining to investments. */
    function eventInvestmentData(uint256 _eventID) public view returns (bool _eventLive, uint256 _eventEnd, uint256 _amountRaised, uint256 _fundingGoal, uint256 _numInvestors, bool _refundEther, bool _withdrawAssetTokens) {
        return (eventMap[_eventID].eventLive, eventMap[_eventID].eventEnd,  eventMap[_eventID].amountRaised, eventMap[_eventID].fundingGoal, eventMap[_eventID].storeKeys.length, eventMap[_eventID].refundEther, eventMap[_eventID].distributeTokens);
    }
    
    /** @dev This function is for mapping an investor's data to the correct event and mapping their key to their InvestorData array. The function is called whenever someone invests.
      * @param _eventID             The eventID that the investor pledged to
      * @param _investorKey         The investor's address
      * @param _amountContributed   Amount that they contributed
      * @param _timeOfContribution  The time of the contribution
      */
    function map (uint256 _eventID, address _investorKey, uint256 _amountContributed, uint256 _timeOfContribution) private  {
        InvestorData memory user;
        user.investorKey = _investorKey;
        user.amountContributed = _amountContributed;
        user.timeOfContribution = _timeOfContribution;
        user.refunded = false;
        user.recieveToken = false;
        investorMap[_eventID][_investorKey].push(user);
    }
     
    /** @dev This function is for allowing an investor to pledge money to a particular crowdfunding event which is denoted by the eventID.
      * @param _eventID  The eventID that the investor wants to pledge to
     */
    function sendInvestment (uint256 _eventID) payable public {
        uint256 _investment = msg.value/1000000000000000000;
        require(eventMap[_eventID].eventLive);
        if (now >= eventMap[_eventID].eventEnd) {
            balance[_eventID][msg.sender] -= msg.value;
            msg.sender.transfer(msg.value);
            endEvent(_eventID);
            return;
        }
        require(_investment * 1000000000000000000 == msg.value);
        if (investorMap[_eventID][msg.sender].length == 0) {
            eventMap[_eventID].storeKeys.push(msg.sender);
        }
        eventMap[_eventID].amountRaised += _investment; 
        balance[_eventID][msg.sender] += _investment;
        map(_eventID, msg.sender, _investment, now);
        emit investmentSent(msg.sender, _eventID);
        if (eventMap[_eventID].amountRaised >= eventMap[_eventID].fundingGoal && eventMap[_eventID].continueAfterGoal == false) {
            endEvent(_eventID);
        }
    }
    
    /** Display an investor's data (singular investment) for a particular event */
    function investorData (uint256 _eventID, uint256 numInvestor, uint256 numInvestment) public view returns (address _investorKey, uint256 totalContributed, uint256 _investorContribution, uint256 _timeOfContribution) {
        address _investor = eventMap[_eventID].storeKeys[numInvestor - 1];
        uint256 _totalContributed;
        for (uint256 i = 0; i < investorMap[_eventID][_investor].length; i++) {
            _totalContributed += investorMap[_eventID][_investor][i].amountContributed;
        }
        return (_investor, _totalContributed, investorMap[_eventID][_investor][numInvestment - 1].amountContributed, investorMap[_eventID][_investor][numInvestment - 1].timeOfContribution);
    }
    
    /** Displays an investor's data for withdrawing tokens/refunding etehr */
    function investorReturnData (uint256 _eventID, uint256 numInvestor, uint256 numInvestment) public view returns  (address _investorKey, bool refunded, uint256 timeOfRefund, bool recieveToken, uint256 timeOfTokenWithdrawal) {
        address _investor = eventMap[_eventID].storeKeys[numInvestor - 1];
        return (_investor, investorMap[_eventID][_investor][numInvestment - 1].refunded, investorMap[_eventID][_investor][numInvestment - 1].timeOfRefund, investorMap[_eventID][_investor][numInvestment - 1].recieveToken, investorMap[_eventID][_investor][numInvestment - 1].timeOfTokenWithdrawal);
    }
    
    Token token;
    
    /** @dev Create a reference to an existing token 
      * @param _tokenAddress  The address of the existing token
      */
    function existingToken (address _tokenAddress) public {
        token = Token(_tokenAddress);
    }
    
    /** @dev Mints tokens for a particular event.
      * @param _eventID     Event to mint tokens for
      */
    function mintToken (uint256 _eventID) public {
         require(msg.sender == eventMap[_eventID].creator);
         require(eventMap[_eventID].distributeTokens);
         require(eventMap[_eventID].mintTokens);
         token.mintTokens(eventMap[_eventID].amountRaised, _eventID, eventMap[_eventID].description);
         eventMap[_eventID].mintTokens = false;
    }
    
    function tokenInfo () public view returns (uint256 _totalSupply, uint256 _eventID, string _eventDescription, address _eventContract) {
        (_totalSupply, _eventID, _eventDescription, _eventContract) = token.tokenInfo();
    }
    
    /** @dev Allows an investor to withdraw asset tokens for a particular event.
    * @param _eventID  Event to withdraw ether from.
    */
    function withdrawAssetTokens(uint256 _eventID) public {
        uint256 _numTokens;
        
        require(eventMap[_eventID].distributeTokens);
        require(investorMap[_eventID][msg.sender][0].amountContributed > 0);
        require(investorMap[_eventID][msg.sender][0].recieveToken == false);
        for (uint256 i = 0; i < investorMap[_eventID][msg.sender].length; i++) {
            _numTokens += investorMap[_eventID][msg.sender][i].amountContributed;
            investorMap[_eventID][msg.sender][i].timeOfTokenWithdrawal = now;
            investorMap[_eventID][msg.sender][i].recieveToken = true;
        }
        token.transfer(msg.sender, _numTokens);
    }
    
    /** @dev Allows an investor to withdraw their ether for a particular event.
      * @param _eventID  Event to withdraw ether from.
      */
    function refundEther (uint256 _eventID) public {
        uint256 _investment;
        
        require(eventMap[_eventID].refundEther);
        require (investorMap[_eventID][msg.sender][0].refunded == false);
        for (uint i = 0; i < investorMap[_eventID][msg.sender].length; i++) {
            _investment += investorMap[_eventID][msg.sender][i].amountContributed; 
            investorMap[_eventID][msg.sender][i].timeOfRefund = now;
            investorMap[_eventID][msg.sender][i].refunded = true;
        }
        _investment *= 1000000000000000000;
        balance[_eventID][msg.sender] -= _investment;
        msg.sender.transfer(_investment);
    }
}

