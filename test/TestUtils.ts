// License-Identifier: MIT
// Functions and Data Structures for Testing Block Miner Game Contracts
// Author: Rohin Knight
/* eslint-disable no-unused-vars */
import { BigNumber } from "ethers";

const U256LENGTH = 77;
export const PUZZLE_W = 20;
export const PUZZLE_H = 14;
export const PUZZLE_W_2X = PUZZLE_W * 2;
export const PUZZLE_H_2X = PUZZLE_H * 2;

/**
 * Tile type constants. Must match values in smart contract.
 */
export enum Tile {
  // Tile types 0-9
  NONE = 0,
  SOFT_BLOCK = 1,
  HARD_BLOCK = 2,
  SOFT_LADDER = 3,
  HARD_LADDER = 4,
  PICK = 5,
  // Tile types not encoded in u256s
  CRYSTAL = 10,
}

/**
 * Move type constants. Must match values in smart contract.
 */
export enum MType {
  MOVE = 0,
  MINE = 1,
  PLACE_BLOCK = 2,
  PLACE_LADDER = 3,
}

/**
 * Move dir constants. Must match values in smart contract.
 */
export enum MDir {
  RIGHT = 1,
  LEFT = 2,
  UP = 3,
  DOWN = 4,
  RIGHT_UP = 5,
  RIGHT_DOWN = 6,
  LEFT_UP = 7,
  LEFT_DOWN = 8,
  WAIT = 9,
}

/**
 * An unencoded puzzle
 */
export class Puzzle {
  tiles: Tile[][] = [];
  playerX: number = 0;
  playerY: number = 0;
  exitX: number = 0;
  exitY: number = 0;
  crystalX: number = 0;
  crystalY: number = 0;

  setPlayer(x: number, y: number): void {
    this.playerX = x;
    this.playerY = y;
  }

  setExit(x: number, y: number): void {
    this.exitX = x;
    this.exitY = y;
  }

  setCrystal(x: number, y: number): void {
    this.crystalX = x;
    this.crystalY = y;
  }
}

/**
 * expands a small 2d test array with a filler tile so it
 * meets the requirements of 20x14 or 40x28 tile puzzle.
 */
export function createExpandedTiles(
  smallTiles: Tile[][],
  newWidth: number,
  newHeight: number,
  fillTile: Tile
): Tile[][] {
  const tiles = [...Array(newHeight)].map(() => Array(newWidth).fill(fillTile));

  for (let y = 0; y < smallTiles.length; ++y) {
    for (let x = 0; x < smallTiles[0].length; ++x) {
      tiles[y][x] = smallTiles[y][x];
    }
  }

  return tiles;
}

/**
 * Convert Puzzle obj to 4 u256 numbers
 */
export function encodePuzzleTo4u256s(puzzle: Puzzle): BigNumber[] {
  const u256s: BigNumber[] = [];
  let dataStr = "";

  const objSpace = 28;
  const deadSpace = objSpace - 4 * 3;
  for (let j = 0; j < deadSpace; ++j) {
    dataStr += "9";
  }

  dataStr += encodeObj3Digits(puzzle.exitX, puzzle.exitY);
  dataStr += encodeObj3Digits(puzzle.playerX, puzzle.playerY);
  dataStr += encodeObj3Digits(puzzle.crystalX, puzzle.crystalY);

  let i: number = objSpace;
  for (let y = PUZZLE_H - 1; y >= 0; --y) {
    for (let x = PUZZLE_W - 1; x >= 0; --x) {
      dataStr += puzzle.tiles[y][x];

      ++i;
      if (i === U256LENGTH) {
        u256s.push(BigNumber.from(dataStr));
        dataStr = "";
        i = 0;
      }
    }
  }

  u256s.reverse();
  return u256s;
}

/**
 * Encodes move arrays in array of BigNumbers
 */
export function getEncodedSolution(
  moveTypes: MType[],
  moveDirs: MDir[]
): BigNumber[] {
  const encoded: BigNumber[] = [];
  let dataStrTemp = "";

  const FIRST_MILESTONE = U256LENGTH - 3;
  const ADDITIONAL_MILESTONE = U256LENGTH - 1;
  let milestone = FIRST_MILESTONE;

  const allDataStrs: string[] = [];

  let i = 0;
  let milestoneCount = 0;
  for (let j = 0; j < moveTypes.length; ++j) {
    dataStrTemp += moveTypes[j];
    dataStrTemp += moveDirs[j];

    i += 2;
    if (i === milestone) {
      // Is it first milestone
      milestoneCount++;
      dataStrTemp = dataStrTemp.split("").reverse().join("");

      if (i === FIRST_MILESTONE) {
        const numMovesStr = String(moveTypes.length).padStart(3, "0");
        dataStrTemp += numMovesStr;
      } else {
        dataStrTemp = "0" + dataStrTemp;
      }

      i = milestoneCount * U256LENGTH;
      milestone = i + ADDITIONAL_MILESTONE;
      allDataStrs.push(dataStrTemp);
      dataStrTemp = "";
    }
  }

  if (dataStrTemp.length > 0) {
    dataStrTemp = dataStrTemp.split("").reverse().join("");
    const numMovesStr = String(moveTypes.length).padStart(3, "0");
    dataStrTemp += numMovesStr;
    allDataStrs.push(dataStrTemp);
  }

  // Add padding to last str
  const lastStrIdx = allDataStrs.length - 1;
  const paddingAmount = U256LENGTH - allDataStrs[lastStrIdx].length;

  let lastStrPadding = "";
  for (let i = 0; i < paddingAmount; ++i) {
    lastStrPadding += "0";
  }

  allDataStrs[lastStrIdx] = lastStrPadding + allDataStrs[lastStrIdx];

  // Store in big number
  for (let i = 0; i < allDataStrs.length; ++i) {
    encoded.push(BigNumber.from(allDataStrs[i]));
  }

  return encoded;
}

/**
 * Encode obj xy position as 3 digits
 * The 3rd digit is the quadrant with a value
 * of 1-4, based on the x and y values.
 *
 *                x
 *          | 0-9 |10-19
 *    ------------------
 *     0-9  |  1  |  2
 *  y ------------------
 *    10-13 |  3  |  4
 */
function encodeObj3Digits(x: number, y: number): string {
  let quadrant: number = 1;
  if (x > 9) {
    x %= 10;
    quadrant = 2;
  }
  if (y > 9) {
    y %= 10;
    quadrant += 2;
  }

  return "" + x + "" + y + "" + quadrant;
}
