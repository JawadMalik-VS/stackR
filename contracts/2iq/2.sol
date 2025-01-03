// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;


contract Mak{
 
    string public message= "Hello My Worrld";

  event MessageUpdated(
  address indexed user,
 string _message
  );

  function updateMessage(string memory _message)public{
   message=_message;
   emit MessageUpdated(msg.sender,_message);

  }
}

contract MyContract{

    event Log(string message);
    function example1(uint value)public{
       require(value>10,"must be greater than 10");    
       emit Log("success");
    }

    function example2(uint value)public{
        if(value<=10){
            revert("must be greater than 10");
        }
       emit Log("success");
    }
}