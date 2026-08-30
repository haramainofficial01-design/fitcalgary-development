import test from 'node:test';import assert from 'node:assert/strict';import { rankResults } from '../src/domain/leaderboards/rank.ts';
const at=new Date('2026-08-29T12:00:00Z');
test('lower time ranks first and tie fallback is stable',()=>{const ranked=rankResults([{id:'b',normalizedMetric:'950',verifiedAt:at},{id:'a',normalizedMetric:'950',verifiedAt:at},{id:'c',normalizedMetric:'1000',verifiedAt:at}],'LOWER_IS_BETTER');assert.deepEqual(ranked.map((item)=>item.id),['a','b','c']);});
test('higher repetitions rank first',()=>{const ranked=rankResults([{id:'a',normalizedMetric:'10',verifiedAt:at},{id:'b',normalizedMetric:'12',verifiedAt:at}],'HIGHER_IS_BETTER');assert.deepEqual(ranked.map((item)=>item.id),['b','a']);});
