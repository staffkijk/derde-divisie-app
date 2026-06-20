// functions/syncTweets.js
// Firebase Cloud Function: haalt originele tweets van @Derde_Div op (geen replies of retweets)
// en schrijft ze naar Firestore (collectie: x_posts).

import fetch from "node-fetch";
import admin from "firebase-admin";
import functions from "firebase-functions";

admin.initializeApp();
const db = admin.firestore();

export const syncTweets = functions
  .region("europe-west1")
  .https.onRequest(async (req, res) => {
    // ✅ CORS-instellingen
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

    // ✅ Behandel preflight request (OPTIONS)
    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }

    try {
      const bearer = process.env.TWITTER_BEARER; // Twitter API key (Bearer token)
      if (!bearer) throw new Error("TWITTER_BEARER ontbreekt in environment");

      // ✅ Vraag de laatste 10 originele tweets (geen replies of retweets)
      const url =
        "https://api.twitter.com/2/users/by/username/Derde_Div/tweets" +
        "?max_results=10" +
        "&tweet.fields=created_at,referenced_tweets,entities,attachments" +
        "&expansions=attachments.media_keys" +
        "&media.fields=url,preview_image_url" +
        "&exclude=replies,retweets";

      const r = await fetch(url, {
        headers: { Authorization: `Bearer ${bearer}` },
      });

      if (!r.ok)
        throw new Error(`Twitter API error: ${r.status} ${r.statusText}`);

      const json = await r.json();
      const tweets = json.data ?? [];
      const mediaMap = new Map();

      // 🔹 Koppel media aan tweets (indien aanwezig)
      if (json.includes && json.includes.media) {
        for (const m of json.includes.media) {
          mediaMap.set(m.media_key, m.url || m.preview_image_url);
        }
      }

      let added = 0;
      for (const t of tweets) {
        const id = t.id;
        const ref = db.collection("x_posts").doc(id);
        const exists = await ref.get();

        if (!exists.exists) {
          // ✅ Probeer media te koppelen (eerste afbeelding/video)
          let mediaUrl = null;
          if (t.attachments && t.attachments.media_keys?.length > 0) {
            const firstKey = t.attachments.media_keys[0];
            mediaUrl = mediaMap.get(firstKey) ?? null;
          }

          await ref.set({
            text: t.text,
            url: `https://x.com/Derde_Div/status/${id}`,
            mediaUrl: mediaUrl,
            createdAt: admin.firestore.Timestamp.fromDate(
              new Date(t.created_at)
            ),
          });

          added++;
        }
      }

      console.log(`✅ ${added} nieuwe tweets toegevoegd.`);
      res.status(200).json({ added });
    } catch (err) {
      console.error("❌ syncTweets error:", err);
      res.status(500).json({ error: err.message });
    }
  });
