import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { Address, BigInt } from "@graphprotocol/graph-ts"
import { BidItemBought } from "../generated/schema"
import { BidItemBought as BidItemBoughtEvent } from "../generated/Contract/Contract"
import { handleBidItemBought } from "../src/contract"
import { createBidItemBoughtEvent } from "./contract-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let buyyer = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let nftAddress = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let tokenId = BigInt.fromI32(234)
    let price = BigInt.fromI32(234)
    let newBidItemBoughtEvent = createBidItemBoughtEvent(
      buyyer,
      nftAddress,
      tokenId,
      price
    )
    handleBidItemBought(newBidItemBoughtEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("BidItemBought created and stored", () => {
    assert.entityCount("BidItemBought", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "BidItemBought",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "buyyer",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "BidItemBought",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "nftAddress",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "BidItemBought",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "tokenId",
      "234"
    )
    assert.fieldEquals(
      "BidItemBought",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "price",
      "234"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
