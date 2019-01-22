# Scatter Protocol

**WIP**: This document is a work in progress.

## Overview

There will be exactly 2 hosters.  They must each stake 1/2 of the value of the bid.

On initial `bid`, a `challenge` is created using the block number of the `bid` transaction as the challenge `seed`. The `seed` added to their unique `hosterIndex` is used to find the `chunkStart` (the first position of a hash). The `chunkStart` plus 1,000 bytes of the file (or until EOF if the file is smaller than 1KB) is the size of the `chunk`. If the `fileSize` is greater than `seed`, subtract `fileSize` from `seed` and try again.

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

The hoster takes `chunk` and hashes it to create their `uniqueHash`. They then sign the hash and submit the `signature` and `uniqueHash` to the chain. Every hoster validates the `uniqueHash` hash and `signature` against the the file they're hosting. If they determine the validation is false, they issue a `challenge`.

Upon a `challenge`, both hosters must complete the `challenge` to `defend` themselves and provide the `hash` and `signature` of of the file using the provided `seed`. A `mediator` joins the fight by fetching the file and performing thier own hash and verification of the provided `uniqueHash`s and `signature`s. They submit their determination.  Whoever wins the `challenge` can `claim` the stake of the loser, splitting it with the `mediator`.  The split is 80:20 in the winning hoster's favor. If a hoster loses a challenge more than `maxLosses` per month their account is banned.

A challenge can only be made every `durationSeconds / 3` interval for up to a maximum of 3 challenges per fire.

Upon completion of the duration, each hoster can make a `claim` on the funds.  If the bid has passed validations and has no open challenges, their balances are updated.

If any participant has a balance, they may `withdraw` at any time.


## Contract Calls

Bidder makes their bid.

    bid(fileHash, fileSize, bidValue)

hoster1 signals intent and puts up their stake, pins the file, performs the hash and signature and submits

    stake(bidId) # with value
    pinned(bidId, uniqueHash, uniqueSignature)

hoster2 does the same

    stake(bidId) # with value
    pinned(bidId, uniqueHash, uniqueSignature)

hoster1 can not confirm hoster2's signature and submits a challenge

    challenge(pinId, seed)

hoster2 defends themselves

    defend(pinId, uniqueHash, uniqueSignature)

Both hosters must complete the challenge

    defend(pinId, uniqueHash, uniqueSignature)

mediator rules. If hoster1 wins, they claim the stake of hoster2 splitting it with the mediator(80/20). This also opens a spot for another hoster to join with their own stake to fill the second spot.

    mediate(challengeId, validity)

With only one hoster now, hoster3 takes the spot

    stake(bidId) # with value
    pinned(bidId, uniqueSignature)

After the duration has been complete and there are no open challenges, each of the hosters can claim their funds and stake.

    claim(bidId) # Updates their balances appropriately

And withdraw whenever, or continue using the funds in the contract.

    withdraw()
