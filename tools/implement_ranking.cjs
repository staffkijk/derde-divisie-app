const fs=require('node:fs');
let p='functions/src/index.ts',s=fs.readFileSync(p,'utf8').replace('retryMatchResult, rebuildDivisionStandings','retryMatchResult, rebuildDivisionStandings, maintainRankingFields');fs.writeFileSync(p,s);
p='lib/features/moderator/moderator_menu_screen.dart';s=fs.readFileSync(p,'utf8').replace('  final String processingStatus;','');
s=s.replace('  final int? homeScore;','  final String processingStatus;\n  final int? homeScore;');
s=s.replace('child: compact ? _buildCompact(hasScore) : _buildWide(hasScore),',`child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        compact ? _buildCompact(hasScore) : _buildWide(hasScore),
        if (match.processingStatus.isNotEmpty)
          Text(match.processingStatus == 'processed' ? 'Verwerkt' : match.processingStatus == 'failed' ? 'Verwerking mislukt' : 'Opgeslagen; verwerking bezig'),
        if (match.processingStatus == 'failed')
          TextButton(onPressed: () async {
            try { await ResultProcessingService.requestProcessing(match.id); }
            catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opnieuw verwerken aanvragen mislukt.'))); }
          }, child: const Text('Opnieuw verwerken')),
      ]),`);fs.writeFileSync(p,s);
p='firestore.indexes.json';const indexes=JSON.parse(fs.readFileSync(p,'utf8'));
for(const field of ['punten_A','punten_B','totalen']) indexes.indexes.push({collectionGroup:'users',queryScope:'COLLECTION',fields:[{fieldPath:field,order:'DESCENDING'},{fieldPath:'rankingName',order:'ASCENDING'},{fieldPath:'__name__',order:'ASCENDING'}]});
indexes.indexes.push({collectionGroup:'matches',queryScope:'COLLECTION',fields:[{fieldPath:'processed',order:'ASCENDING'},{fieldPath:'status',order:'ASCENDING'}]});
for(const field of ['punten_A','punten_B','totalen']) indexes.indexes.push({collectionGroup:'users',queryScope:'COLLECTION',fields:[{fieldPath:field,order:'ASCENDING'},{fieldPath:'rankingName',order:'ASCENDING'}]});
fs.writeFileSync(p,JSON.stringify(indexes,null,2)+'\n');
