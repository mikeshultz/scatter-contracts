# Scatter Protocol

**WIP**: This document is a work in progress.

## Overview

There will be exactly 2 hosters.  They must each stake 1/2 of the value of the bid.

On initial bid, a challenge is created for with the block number of the bid being the challenge `seed`. The `seed` is used to find the first position of a hash of 1,000 bytes of the file. A `chunk` of the file is pulled from position `seed` for 1000bytes or until EOF if the file is smaller than 1KB.  If the entire size of the file is greater than `seed`, subtract the size of the file from `seed` and try again.

    seed = blockNumber
    if seed > fileSize:
        chunkStart = seed - fileSize + hosterSeedIndex
    else:
        chunkStart = seed + hosterSeedIndex
        
    if len(file) < chunkStart + 1000:
        chunk = file[chunkStart:len(file)]
    else:
        chunk = file[chunkStart:1000]
    uniqueHash = hash(chunk)
    signature = sign(uniqueHash)

The hoster takes `chunk` and hashes it to create their `uniqueHash`. They then sign the hash and submit the `signature` and `uniqueHash` to the chain. Every hoster validates the `uniqueHash` hash and `signature` against the the file they're hosting. If they determine the validation is false, they issue a `dispute`.

Upon a `dispute`, a `mediator` joins the fight by fetching the file and performing thier own hash and verification of the provided `uniqueHash`s and `signature`s. They submit their determination.  Whoever wins the challeng can claim the stake of the loser, splitting it with the `mediator`. If a hoster loses more than `maxLosses` their account is banned.

Upon completion of the duration, each hoster can make a `claim` on the funds.  If the bid has passed validations and has no open challenges, their balances are updated.

If any participant has a balance, they may `withdraw` at any time.


## Contract Calls

Bidder makes their bid.

    bid(fileHash, fileSize, bidValue)

hoster1 signals intent, pins the file, performs the hash and signature and submits

    stake(bidId) # with value
    pinned(bidId, uniqueSignature)

hoster2 signals intent, pins the file, performs the hash and signature and submits

    stake(bidId) # with value
    pinned(bidId, uniqueSignature)

hoster1 can not confirm hoster2's signature and submits a challenge

    challenge(pinId, seed)

hoster2 defends themselves

    defend(pinId, uniqueSignature)

Both hosters must complete the challenge

    defend(pinId, uniqueSignature)

mediator rules. If hoster1 wins, they claim the stake of hoster2 splitting it with the mediator(80/20). This also opens a spot for another hoster to join with their own stake to fill the second spot.

    mediate(challengeId, validity)

With only one hoster now, hoster3 takes the spot

    stake(bidId) # with value
    pinned(bidId, uniqueSignature)

After the duration has been complete and there are no open challenges, each of the hosters can claim their funds and stake.

    claim(bidId) # Updates their balances appropriately

And withdraw whenever, or continue using the funds in the contract.

    withdraw()
