'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { selectSyntheticAvatar, resolveTeam } = require('../../tools/synthetic_avatar_selector');
const teams = [
  { id: 'sparta-nijkerk', name: 'Sparta Nijkerk', logoPath: 'assets/images/logo_SpartaNijkerk.png', nameTokens: ['Sparta', 'Nijkerk'] },
  { id: 'dvs33-ermelo', name: "DVS'33 Ermelo", logoPath: 'assets/images/logo_DVS33Ermelo.png', nameTokens: ['DVS33', 'Ermelo'] },
];
test('selector is deterministisch', () => assert.deepEqual(selectSyntheticAvatar({ uid: 'x', favoriteTeamSlug: 'sparta-nijkerk' }, teams), selectSyntheticAvatar({ uid: 'x', favoriteTeamSlug: 'sparta-nijkerk' }, teams)));
test('De Nijkerker koppelt uitsluitend aan Sparta Nijkerk', () => { const match = resolveTeam({ displayName: 'De Nijkerker' }, teams); assert.equal(match.team.id, 'sparta-nijkerk'); assert.notEqual(match.team.id, 'dvs33-ermelo'); });
test('onbekende binding valt terug op voetbal of leeg', () => assert.notEqual(selectSyntheticAvatar({ uid: 'onbekend', displayName: 'Supporter' }, teams).kind, 'club'));
test('favoriete club bepaalt clubmatch semantisch', () => assert.equal(resolveTeam({ favorieteClub: "DVS'33 Ermelo", displayName: 'De Nijkerker' }, teams).team.id, 'dvs33-ermelo'));