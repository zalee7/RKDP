/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const assert = require("node:assert/strict");

// Atomic serialized transaction double; not a security-rules/emulator substitute.
class MemoryDB {
  constructor() {
    this.documents = new Map(); this.queue = Promise.resolve();
  }
  doc(path) {
    return {path, get: async () => this.snapshot(path)};
  }
  snapshot(path) {
    const value = this.documents.get(path);
    return {exists: value !== undefined, data: () => structuredClone(value)};
  }
  set(path, data) {
    this.documents.set(path, structuredClone(data));
  }
  runTransaction(body) {
    const work = this.queue.then(async () => {
      const writes = [];
      const result = await body({
        get: async (ref) => {
          assert.equal(writes.length, 0, "reads must precede writes"); return this.snapshot(ref.path);
        },
        create: (ref, value) => {
          assert.ok(!this.documents.has(ref.path)); writes.push([ref.path, value]);
        },
        set: (ref, value) => writes.push([ref.path, value]),
        update: (ref, value) => {
          assert.ok(this.documents.has(ref.path)); writes.push([ref.path, {...this.snapshot(ref.path).data(), ...value}]);
        },
      });
      for (const [path, value] of writes) this.set(path, value);
      return result;
    });
    this.queue = work.catch(() => {});
    return work;
  }
}
module.exports = {MemoryDB};
