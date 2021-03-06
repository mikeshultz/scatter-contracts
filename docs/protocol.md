# Scatter Protocol

**WIP**: This document is a work in progress.

## Overview

There will be exactly 2 hosters.  They must each stake 1/2 of the value of the bid.

On initial `bid`, a `challenge` is created using the block hash of the `bid` transaction as the challenge `seed`. The `seed` added to the hoster's `address`, hashed, and the modulo of the hash is used to find the `chunkStart` (the first position of a chunk to hash). The size of the `chunk` is determined by `chunkStart` plus 1,000 bytes of the file. If the `chunkStart + chunkSize` is greater than `fileSize`, only take the chunk to EOF.

    seed = blockHash
    chunkSize = 1000

    if seed > fileSize:
        chunkStart = hash(seed + hosterAddress) % filesize - chunkSize
    else:
        chunkStart = hash(seed + hosterAddress) % filesize

    if chunkStart + chunkSize > fileSize:
        chunkSize = fileSize - chunkStart

    chunk = file[chunkStart:chunkStart + chunkSize]
    uniqueHash = hash(chunk)
    signature = sign(uniqueHash)

The hoster takes `chunk` and hashes it to create their `uniqueHash`. They then sign the hash and submit the `signature` and `uniqueHash` to the chain. Every hoster validates the `uniqueHash` and `signature` against the the file they're hosting. If they determine the validation is false, they issue a `challenge`.

Upon a `challenge`, both hosters must complete the `challenge` to `defend` themselves and provide the `uniqueHash` and `signature` of of the file using the provided `seed`. A `mediator` joins the fight by fetching the file and performing thier own hash and verification of the provided `uniqueHash`s and `signature`s. They submit their determination.  Whoever wins the `challenge` can `claim` the stake of the loser, splitting it with the `mediator`. If a hoster loses a challenge more than `maxLosses` per month their account is banned.

A challenge can only be made every `durationSeconds / 3` interval for up to a maximum of 3 challenges per fire.

Upon completion of the duration, each hoster can make a `claim` on the funds.  If the bid has passed validations and has no open challenges, their balances are updated.

If any participant has a balance, they may `withdraw` at any time.


## Contract Calls

Bidder makes their bid.

    bid(fileHash, fileSize, bidValue) # with value

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

Then mediator makes their ruling. If hoster1 wins, they claim the stake of hoster2 splitting it with the mediator(80/20)

    mediate(challengeId, validity)

This also opens a spot for hoster3 to join with their own stake to fill the spot lost from the failed challenge.

    stake(bidId) # with value
    pinned(bidId, uniqueSignature)

After the duration has been complete and there are no open challenges, each of the hosters can claim their funds and stake.

    claim(bidId) # Updates their balances appropriately

And withdraw whenever, or continue using the funds in the contract.

    withdraw() # Transfers value to the sender
