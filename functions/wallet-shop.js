/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";

const {readWallet, commitWallet, dayKey, check, validID, validUID} = require("./wallet-ledger");
const avatarCategories = ["Avatar Head", "Avatar Face", "Avatar Outfit", "Avatar Aura"];
const shopCategories = ["Name Titles", "Board / Background Themes", "Tile Themes", "Card Themes"];
const fields = ["equippedTitle", "equippedBoardTheme", "equippedTileTheme", "equippedCardTheme", "equippedNumberFont",
  "equippedCellBorder", "equippedAvatarHead", "equippedAvatarFace", "equippedAvatarOutfit", "equippedAvatarAura", "equippedAvatarPose"];

function rotationSeed(day, key, slot) {
  let value = BigInt(day) * 1103n + BigInt(slot) * 97n;
  for (const char of key) value = BigInt.asIntN(64, value * 31n + BigInt(char.codePointAt(0)));
  return value;
}
function shuffle(items, seed) {
  let s = BigInt.asUintN(64, seed * 6364136223846793005n + 1442695040888963407n);
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    s = BigInt.asUintN(64, s * 6364136223846793005n + 1442695040888963407n);
    const j = Number(s >> 33n) % (i + 1);
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}
function rotationIDs(catalog, now) {
  const day = Math.floor(now / 86400000);
  const fallback = {common: ["common", "rare", "epic", "legendary"], rare: ["rare", "epic", "common", "legendary"],
    epic: ["epic", "legendary", "rare", "common"], legendary: ["legendary", "epic", "rare", "common"]};
  const selected = new Set();
  for (const group of [...shopCategories.map((key) => ({key, categories: [key]})), {key: "avatar_shop", categories: avatarCategories}]) {
    const pool = catalog.items.filter((i) => i.price > 0 && i.available && group.categories.includes(i.category));
    const premiumSeed = rotationSeed(day, group.key, 42);
    const roll = Number((premiumSeed < 0n ? -premiumSeed : premiumSeed) % 100n);
    const rarities = group.key === "avatar_shop" ? ["common", "rare", "epic", "legendary"] :
      ["common", "common", "rare", roll < 60 ? "rare" : roll < 85 ? "epic" : "legendary"];
    const picks = new Set();
    for (let slot = 0; slot < 4; slot++) {
      for (const rarity of fallback[rarities[slot]]) {
        const candidates = pool.filter((i) => i.rarity === rarity && !picks.has(i.id));
        if (candidates.length) {
          picks.add(shuffle(candidates, rotationSeed(day, group.key, slot))[0].id); break;
        }
      }
    }
    for (const item of shuffle(pool, rotationSeed(day, group.key, 99))) {
      if (picks.size >= 4) break;
      picks.add(item.id);
    }
    picks.forEach((id) => selected.add(id));
  }
  return selected;
}

function createWalletShop({db, clock = Date.now}) {
  async function gate(tx) {
    const control = (await tx.get(db.doc("economyPrivate/control"))).data();
    check(control?.walletMigrationReady === true && control?.walletOperationsEnabled === true, "Wallet operations are paused");
  }
  async function catalog(tx) {
    const value = (await tx.get(db.doc("economyPrivate/cosmeticCatalog"))).data();
    check(value?.version === 1 && Array.isArray(value.items) && Array.isArray(value.defaultIDs) &&
      new Set(value.items.map((i) => i.id)).size === value.items.length &&
      value.items.every((i) => validID(i.id) && Number.isSafeInteger(i.price) && i.price >= 0 && fields.includes(i.slot)),
    "Trusted cosmetic catalog unavailable");
    return value;
  }

  async function claimDaily(uid) {
    check(validUID(uid), "Invalid account");
    return db.runTransaction(async (tx) => {
      const now = clock();
      const today = dayKey(now);
      const context = await readWallet(db, tx, uid, `daily_${today}`);
      if (context.existing) return context.existing;
      await gate(tx);
      // Preserve already-claimed days from the legacy migration without paying again.
      const delta = context.wallet.dailyClaimDay === today ? 0 : 50;
      return commitWallet(tx, context, {kind: "dailyClaim", delta, now,
        walletUpdates: {dailyClaimDay: today},
        userUpdates: {coinWallet: {...context.user.coinWallet, claimedDailyCoinDay: today}}, receipt: {day: today}});
    });
  }

  async function purchaseCosmetic(uid, data) {
    check(validUID(uid) && validID(data.itemID), "Invalid cosmetic");
    return db.runTransaction(async (tx) => {
      const context = await readWallet(db, tx, uid, `cosmetic_${data.itemID}`);
      if (context.existing) return context.existing;
      await gate(tx);
      const c = await catalog(tx);
      const item = c.items.find((i) => i.id === data.itemID);
      check(item, "Unknown cosmetic");
      check(data.expectedPrice === undefined || data.expectedPrice === item.price, "Shop price changed");
      const owned = new Set([...(context.user.cosmetics?.purchasedIDs ?? []), ...c.defaultIDs]);
      const wasOwned = owned.has(item.id);
      const now = clock();
      check(wasOwned || (item.available && rotationIDs(c, now).has(item.id)), "This item is not in today's shop");
      owned.add(item.id);
      return commitWallet(tx, context, {kind: "cosmeticPurchase", delta: wasOwned ? 0 : -item.price, now,
        receipt: {itemID: item.id, coinsSpent: wasOwned ? 0 : item.price},
        userUpdates: {cosmetics: {...context.user.cosmetics, purchasedIDs: [...owned], [item.slot]: item.id}}});
    });
  }

  async function equip(uid, data) {
    check(validUID(uid) && data.selection && typeof data.selection === "object" && !Array.isArray(data.selection), "Invalid selection");
    const keys = Object.keys(data.selection);
    check(keys.length > 0 && keys.every((key) => fields.includes(key) || key === "customAvatarBodyHex"), "Invalid selection fields");
    return db.runTransaction(async (tx) => {
      await gate(tx);
      const wallet = (await tx.get(db.doc(`coinWallets/${uid}`))).data();
      const userRef = db.doc(`users/${uid}`);
      const user = (await tx.get(userRef)).data();
      check(wallet?.version === 1 && user && !user.deletedAt, "Wallet migration required");
      const c = await catalog(tx);
      const owned = new Set([...(user.cosmetics?.purchasedIDs ?? []), ...c.defaultIDs]);
      const cosmetics = {...user.cosmetics};
      for (const key of keys) {
        const value = data.selection[key];
        if (cosmetics[key] === value) continue;
        if (key === "customAvatarBodyHex") {
          check(typeof value === "string" && /^[0-9A-Fa-f]{6}$/.test(value), "Invalid body color");
          cosmetics[key] = value.toUpperCase();
        } else {
          check(validID(value) && owned.has(value) && c.items.some((i) => i.id === value && i.slot === key), "Cosmetic is not owned in that slot");
          cosmetics[key] = value;
        }
      }
      tx.update(userRef, {cosmetics});
      return {saved: true};
    });
  }
  return {claimDaily, purchaseCosmetic, equip};
}
module.exports = {createWalletShop, rotationIDs};
