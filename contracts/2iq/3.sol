// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Human {
   string  message;
    string  msg2;
     string  msg1;
      string  msg3;
  function Speak(bool speak)public {
   message="Let the World heal ";
    speak= true;

  }

  function Talkers()public  view returns(string memory){
     return message;
  }

  function Listeners() public view returns(string memory) {
     return message;
  }


  function walk() public{
    msg2="Let's go to Walk ";
  }

  function Eat()public{
   msg1="Let's go and Eat ";
  }

  function Sleep()public{
     msg3="Let's Sleep Now ";
  }


  function Hungers()public view returns (string memory){
     return msg1;

  }

    function Walkers()public view returns (string memory){
     return msg2;

  }
    function Sleepers()public view returns (string memory){
     return msg3;

  }

}