// License-Identifier: MIT
// Functions and Data Structures for Testing Block Miner Game Contracts
// Author: Rohin Knight
import { BigNumber } from "ethers";

/* eslint-disable no-unused-vars */
const U256LENGTH = 77;
export const PUZZLE_WIDTH = 20;
export const PUZZLE_HEIGHT = 14;

/**
 * Tile enums. Must match values in smart contract.
 */
export enum Tile {
  None = 0,
  Soft = 1,
  HardBlock = 2,
  Ladder = 3,
  HardLadder = 4,
  Pickhammer = 4,

  Crystal = 10,
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
  for (let y = PUZZLE_HEIGHT - 1; y >= 0; --y) {
    for (let x = PUZZLE_WIDTH - 1; x >= 0; --x) {
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
