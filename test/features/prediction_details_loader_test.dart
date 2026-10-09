import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:derde_divisie/features/voorspellen/prediction_details_loader.dart';
void main() {
  test('L: 612 predictions use four pages and bounded match queries for either user',() async {
    for(final user in ['own','other']) {
      var pages=0,matchRequests=0;
      final loader=PredictionDetailsLoader(pageReader:(source,owner,uid,cursor)async {
        expect(uid,user);if(source!='season'||owner!='userId')return [];
        pages++;final start=cursor==null?0:int.parse(cursor)+1;
        return List.generate((612-start).clamp(0,200),(i)=>PredictionDocument('${start+i}',{'matchId':'m${start+i}','userId':uid}));
      },matchReader:(ids) async {expect(ids.length,lessThanOrEqualTo(30));matchRequests++;return {for(final id in ids)id:{'status':'scheduled'}};});
      final result=await loader.load(user);expect(result.predictions.length,612);expect(result.matches.length,612);
      expect(pages,4);expect(matchRequests,21);
    }
  });
  test('K: empty predictions need no match downloads and a failed query surfaces',() async {
    final loader=PredictionDetailsLoader(pageReader:(_,__,___,____)async=>[],matchReader:(_)async=>throw StateError('unexpected'));
    expect((await loader.load('empty')).predictions,isEmpty);
    final failed=PredictionDetailsLoader(pageReader:(_,__,___,____)async=>throw StateError('offline'),matchReader:(_)async=>{});
    await expectLater(failed.load('user'),throwsStateError);
  });
  test('duplicate legacy and season predictions choose latest consistently',() async {
    final loader=PredictionDetailsLoader(pageReader:(source,owner,_,__)async=>owner=='uid'?[PredictionDocument(source,{
      'matchId':'m','uid':'user','scoreThuis':source=='season'?2:1,'timestamp':Timestamp.fromMillisecondsSinceEpoch(source=='season'?2:1),
    })]:[],matchReader:(ids)async=>{'m':{}});
    expect((await loader.load('user')).predictions['m']!['scoreThuis'],2);
  });
}
