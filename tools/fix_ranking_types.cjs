const fs=require('node:fs');
let p='lib/features/voorspellen/ranking_repository.dart',s=fs.readFileSync(p,'utf8');
s=s.replace('class RankingRepository {',`class OwnRankingPosition {
  const OwnRankingPosition(this.entry, this.position);
  final RankingEntry entry;
  final int position;
}
class RankingRepository {`).replace('Future<(RankingEntry, int)?>','Future<OwnRankingPosition?>').replace('return (RankingEntry(uid,data),1+counts.fold<int>(0,(total,c) => total+(c.count ?? 0)));','return OwnRankingPosition(RankingEntry(uid,data),1+counts.fold<int>(0,(total,c) => total+(c.count ?? 0)));');fs.writeFileSync(p,s);
p='lib/features/voorspellen/ranking_screen.dart';s=fs.readFileSync(p,'utf8').replace('(RankingEntry, int)? _own;','OwnRankingPosition? _own;').replaceAll('_own!.$1','_own!.entry').replaceAll('_own!.$2','_own!.position');
s=s.replace("    return ListTile(onTap:() => _actions(user),",`    final ImageProvider? image = avatar.startsWith('http') ? NetworkImage(avatar) : avatar.startsWith('assets/') ? AssetImage(avatar) : null;
    return ListTile(onTap:() => _actions(user),`).replace("backgroundImage:avatar.startsWith('http') ? NetworkImage(avatar) : avatar.startsWith('assets/') ? AssetImage(avatar) : null,",'backgroundImage:image,');fs.writeFileSync(p,s);
