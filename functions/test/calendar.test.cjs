const test = require('node:test');
const assert = require('node:assert/strict');
const {buildCalendar, escapeIcs} = require('../lib/calendar.js');
const matches = [
  {id:'a_1',division:'A',round:1,date:'2026-08-15',kickoffTime:'14:30',homeTeam:'ACV',awayTeam:'DOVO',homeTeamSlug:'acv',awayTeamSlug:'vv_dovo',status:'scheduled'},
  {id:'b_1',division:'B',round:1,date:'2026-12-20',kickoffTime:'14:00',homeTeam:'RBC',awayTeam:'VVSB',homeTeamSlug:'rbc',awayTeamSlug:'vvsb',status:'finished',homeScore:2,awayScore:1},
  {id:'a_2',division:'A',round:2,date:'2026-10-25',kickoffTime:'15:00',homeTeam:'DOVO',awayTeam:'ACV',homeTeamSlug:'vv_dovo',awayTeamSlug:'acv',status:'postponed'},
];
const teams=[{id:'acv',clubId:'acv',name:'ACV',venueName:'Seizoensveld',venueCity:'Assen'}];
const clubs=[{id:'acv',name:'ACV',venueName:'Centraal veld',venueAddress:'Straat 1',venuePostalCode:'1234 AB',venueCity:'Centraalstad'}];
const make=(extra={})=>buildCalendar({seasonId:'2026-2027',matches,teams,baseUrl:'https://derdediv.nl',generatedAt:new Date('2026-08-01T10:00:00Z'),...extra});
test('all and division feeds filter',()=>{assert.match(make(),/UID:a_1@derdediv.nl/);assert.match(make(),/UID:b_1@derdediv.nl/);assert.doesNotMatch(make({division:'A'}),/UID:b_1/);assert.doesNotMatch(make({division:'B'}),/UID:a_1/);});
test('team feed has home and away only',()=>{const f=make({teamId:'acv'});assert.match(f,/UID:a_1/);assert.match(f,/UID:a_2/);assert.doesNotMatch(f,/UID:b_1/);});
test('UID stays stable after change',()=>{assert.match(make({matches:[{...matches[0],kickoffTime:'16:00',homeScore:3,awayScore:2}]}),/UID:a_1@derdediv.nl/);});
test('Amsterdam timezone and DST',()=>{const f=make();assert.match(f,/TZID:Europe\/Amsterdam/);assert.match(f,/DTSTART;TZID=Europe\/Amsterdam:20260815T143000/);assert.match(f,/BYMONTH=3;BYDAY=-1SU/);});
test('escaping',()=>assert.equal(escapeIcs('a,b;c\\d\ne'),'a\\,b\\;c\\\\d\\ne'));
test('central club venue is used',()=>{assert.match(make({teams:[{id:'acv',clubId:'acv',name:'ACV'}],clubs}),/LOCATION:Centraal veld\\, Straat 1\\, 1234 AB Centraalstad/);});
test('match venue overrides season and central club venue',()=>{const feed=make({clubs,matches:[{...matches[0],venueName:'Ander veld',venueCity:'Utrecht'}]});assert.match(feed,/LOCATION:Ander veld\\, Straat 1\\, 1234 AB Utrecht/);});
test('season team venue overrides central club venue',()=>{const feed=make({clubs});assert.match(feed,/LOCATION:Seizoensveld\\, Straat 1\\, 1234 AB Assen/);});
test('club without venue has no location',()=>{assert.doesNotMatch(make({matches:[matches[1]],teams:[],clubs:[{id:'rbc',name:'RBC'}]}),/LOCATION:/);});
test('unknown clubId has no central location',()=>{assert.doesNotMatch(make({matches:[matches[0]],teams:[{id:'acv',clubId:'unknown',name:'ACV'}],clubs}),/LOCATION:/);});
test('missing clubId falls back to existing team id',()=>{assert.match(make({matches:[matches[0]],teams:[{id:'acv',name:'ACV'}],clubs}),/LOCATION:Centraal veld/);});
test('missing clubId falls back to existing team name',()=>{assert.match(make({matches:[matches[0]],teams:[{id:'legacy-acv',name:'ACV'}],clubs}),/LOCATION:Centraal veld/);});
test('statuses and result',()=>{const f=make({matches:[{...matches[0],id:'p',status:'postponed'},{...matches[0],id:'c',status:'canceled'},{...matches[0],id:'a',status:'abandoned'},{...matches[0],id:'f',status:'finished',homeScore:2,awayScore:1}]});assert.match(f,/\[Uitgesteld\]/);assert.match(f,/STATUS:CANCELLED/);assert.match(f,/\[Gestaakt\]/);assert.match(f,/SUMMARY:ACV 2 – 1 DOVO/);});
