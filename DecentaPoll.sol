// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Main contract for the decentralized polling application
contract PollDApp {
    // Defines the structure of a Poll with all necessary information
    struct Poll {
        uint256 id;                // Unique identifier for the poll
        address creator;           // Ethereum address of the poll creator
        string question;           // The main question being asked in the poll
        string[] options;          // Array of available voting options
        uint256[] voteCounts;      // Array tracking the number of votes for each option
        uint256 totalVotes;        // Total votes cast in this poll
        bool active;               // Indicates if the poll is active or not
        uint256 createdAt;         // Timestamp when the poll was created

    }

    uint256 private pollIdCounter; // Counter to generate unique IDs for new polls
    mapping(uint256 => Poll) public polls; // Maps poll IDs to their Poll data
    uint256[] public allPollIds;   // Array to keep track of all created poll IDs
    
    // Maps user addresses to poll IDs to track if they've already voted
    mapping(address => mapping(uint256 => bool)) private hasVoted;

    // Event emitted when a new poll is created
    event PollCreated(
        uint256 indexed pollId,    // Indexed to allow efficient filtering
        address indexed creator,   // Indexed to allow efficient filtering
        string question
    );
    mapping(bytes32 => bool) public existingQuestions;

    // Event emitted when a vote is cast
    event VoteCast(uint256 indexed pollId, uint256 optionIndex);

    // Event emitted when a poll is deleted
    event PollDeleted(uint256 indexed pollId);

    // Function to create a new poll with a question and multiple choice options
    function createPoll(
        string memory _question,
        string[] memory _options
    ) public {
        // Validate that there are at least 2 options
            require(_options.length >= 2, "A poll needs at least 2 options");
            
            bytes32 questionHash = keccak256(abi.encodePacked(_question));
            require(!existingQuestions[questionHash], "Poll with this question already exists");
            existingQuestions[questionHash] = true;

        // Validate that there aren't too many options
        require(
            _options.length <= 10,
            "A poll cannot have more than 10 options"
        );

        // Generate a new unique poll ID
        uint256 pollId = pollIdCounter++;
        // Create an array to track votes for each option, initially all zeros
        uint256[] memory voteCounts = new uint256[](_options.length);
        
        // Create the poll and store it in the mapping
        polls[pollId] = Poll({
            id: pollId,
            creator: msg.sender,           // The person calling this function becomes the creator
            question: _question,
            options: _options,
            voteCounts: voteCounts,        // Initialize with zero votes
            totalVotes: 0,
            createdAt: block.timestamp,    // Current block timestamp
            active: true                   // Poll is active upon creation
        });
        
        // Add the poll ID to the list of all polls
        allPollIds.push(pollId);
        
        // Emit an event to notify listeners about the new poll
        emit PollCreated(pollId, msg.sender, _question);
    }

    // Function for users to vote on a poll
    function vote(uint256 _pollId, uint256 _optionIndex) public {
        // Get the poll data from storage
        Poll storage poll = polls[_pollId];
        
        // Check if the poll exists and is active
        require(poll.active, "Poll does not exist or is not active");
        // Check if the option index is valid
        require(_optionIndex < poll.options.length, "Invalid option");
        // Check if the user has already voted on this poll
        require(
            !hasVoted[msg.sender][_pollId],
            "You have already voted on this poll"
        );

        // Increment the vote count for the selected option
        poll.voteCounts[_optionIndex]++;
        // Increment the total vote count for the poll
        poll.totalVotes++;
        // Mark that this user has voted on this poll
        hasVoted[msg.sender][_pollId] = true;
        
        // Emit an event to notify listeners about the vote
        emit VoteCast(_pollId, _optionIndex);
    }

    // Function to get detailed information about a specific poll
    function getPoll(
        uint256 _pollId
    )
        public
        view    // View function doesn't modify state, only reads data
        returns (
            uint256 id,
            address creator,
            string memory question,
            string[] memory options,
            uint256[] memory voteCounts,
            uint256 totalVotes,
            bool active
        )
    {
        // Get the poll data from storage
        Poll storage poll = polls[_pollId];
        // Check if the poll exists and is active
        require(poll.active, "Poll does not exist or is not active");
        
        // Return all poll information
        return (
            poll.id,
            poll.creator,
            poll.question,
            poll.options,
            poll.voteCounts,
            poll.totalVotes,
            poll.active
        );
    }

    // Function to get the total number of polls
    function getPollCount() public view returns (uint256) {
        return allPollIds.length;
    }

    // Function to check if a specific user has already voted on a poll
    function hasUserVoted(
        address _user,
        uint256 _pollId
    ) public view returns (bool) {
        return hasVoted[_user][_pollId];
    }

    // Function to reset all polls (for admin purposes or testing)
    function resetAllPolls() public {
        // Iterate through all poll IDs
        for (uint256 i = 0; i < allPollIds.length; i++) {
            uint256 pollId = allPollIds[i];
            // Set each poll to inactive
            polls[pollId].active = false;
        }
        // Clear the array of poll IDs
        delete allPollIds;
        // Reset the poll ID counter
        pollIdCounter = 0;
    }

    // Function to allow the creator to delete their poll
    function deletePoll(uint256 _pollId) public {
        Poll storage poll = polls[_pollId];

        // Ensure the poll exists and is active
        require(poll.active, "Poll does not exist or is already deleted");

        // Ensure only the poll creator can delete it
        require(msg.sender == poll.creator, "Only the creator can delete this poll");

        // Mark the poll as inactive
        poll.active = false;

         // Remove poll ID from the allPollIds array
        for (uint256 i = 0; i < allPollIds.length; i++) {
            if (allPollIds[i] == _pollId) {
                allPollIds[i] = allPollIds[allPollIds.length - 1];
                allPollIds.pop();
                break;
            }
        }

        // Emit event
        emit PollDeleted(_pollId);
    }


    // Function to get a sorted list of polls by popularity (number of votes)
    function getLeaderboard() public view returns (uint256[] memory) {
        // Create a copy of the poll IDs array
        uint256[] memory pollIds = new uint256[](allPollIds.length);
        for (uint256 i = 0; i < allPollIds.length; i++) {
            pollIds[i] = allPollIds[i];
        }
        
        // Sort the array using bubble sort algorithm (descending order by total votes)
        for (uint256 i = 0; i < pollIds.length; i++) {
            for (uint256 j = 0; j < pollIds.length - i - 1; j++) {
                // Compare the total votes of adjacent polls
                if (
                    polls[pollIds[j]].totalVotes < polls[pollIds[j + 1]].totalVotes
                ) {
                    // Swap the poll IDs if they're in the wrong order
                    uint256 temp = pollIds[j];
                    pollIds[j] = pollIds[j + 1];
                    pollIds[j + 1] = temp;
                }
            }
        }
        
        // Return the sorted array of poll IDs
        return pollIds;
    }
}
