# Scatter Protocol

**WIP**: This document is a work in progress.

## Overview

There are two types of particpants involved in the system.  The bidder and the pinner.  The bidder needs a file pinned on IPFS and the pinners want to make a little Ether.  The general steps of the protocol go as follows:

1) The bidder Joseph constructs a bid with a value, minimum required pinners, and duration
2) Pinner Andy finds these terms agreeable, so he puts up a stake of half of the bid value
3) Pinner Bruce does the same.
4) Scatter creates a *challenge*, that both Andy and Bruce need to complete. (Details of the challenge are below.)
5a) The challenge is a success, proving that both Andy and Bruce posess a copy of the file
5b) The challenge fails, and both of their stakes are burned
5c) Bruce fails to respond to the challenge in time.  His stake is burned leaving a slot open for a new pinner to complete his half of the challenge.
6) The duration has passed, the stakes are returned, and the bid value is split between the pinners.

Step 4 can be repeated up to 3 times of the life of the staked bid.

## Mutually Assured Destruction

This is the simplest way to conceptually enforce good actors without a complex form of validators and dispute resolution/arbitration.  Basically, if the pinners can not prove that they both have a copy of the file, they both lose their stakes.  This process is satisfied through a challenge process that asks the pinners to both complete a challenge.  This challenge requires them to both present two halves the result to prove they both see the same data.

If any of the pinners fail the challenge outright, all of their stakes are burned.

## Chunk Derivation

A "chunk" in this context, is a binary piece of the pinned file.  The processes to determine which chunks needs to be hashed need to be fairly hard to fake and repeatable between all participants.  Given the same state and parameters, the same chunks of a file must be chosen in an idempotent way.

    nonce = 1  # or 2, given by whether this is hash1 or hash2
    seed = blockHash  # The blockHash of the block the challenge was made
    chunkSize = 1000
    chunkStart = hash(seed + hosterAddress + nonce) % filesize
    if seed > fileSize:
        chunkStart -= chunkSize

    if chunkStart + chunkSize > fileSize:
        chunkSize = fileSize - chunkStart

    chunk = file[chunkStart:chunkStart + chunkSize]

## Challenge

A challenge is a request for pinners to verify they posess the files. One is created once both stakes have been provided.  A challenge can be triggered by anyone, but only every `durationSeconds / 3` interval for up to a maximum of 3 challenges per file. Each pinner is given a nonce, which is just the order that they staked the bid. This nonce is used to derive the chunk they're to sign, and which half of the hashes to provide.

If the pinner's nonce is `1`, they provide the first half of the hashes and sign the first hash.  If the nonce is `2`, they provide the second half of the hashes and sign the second hash.

In the ongoing example, Andy's `nonce` is `1`, and Bruce's `nonce` is `2`.  

### Pinner Andy

Andy computes the two chunks according to the protocol, hashes them both, and signs the first hash.  He submits the first half of each hash and his signature of the first hash to the contract.

    chunk1 = derive_chunk(file, nonce=1)
    chunk2 = derive_chunk(file, nonce=2)
    hash1 = hash(chunk1)
    hash2 = hash(chunk2)
    sig1 = sign(hash1)
    scatter.defend(hash1[:32], hash2[:32], sig1)

### Pinner Bruce

Andy computes the two chunks according to the protocol, hashes them both, and signs the second hash.  He submits the second half of each hash and his signature of the second hash to the contract.

    chunk1 = derive_chunk('a', file, nonce=1)
    chunk2 = derive_chunk('b', file, nonce=2)
    hash1 = hash(chunk1)
    hash2 = hash(chunk2)
    sig2 = sign(hash2)
    scatter.defend(hash1[32:], hash2[32:], sig2)

### Scatter Contract

The contract combines these hashes and verifies each pinner's signature of these hashes, proving that both pinners are looking at the same file.

    hash1 = hash1_a + hash1_b
    hash2 = hash2_a + hash2_b
    verify_signature(hash1, sig1)
    verify_signature(hash2, sig2)
