const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function requireUUIDLocalId(localId: string) {
  if (!uuidPattern.test(localId)) {
    throw new Error("localId must be a UUID string.");
  }
}
