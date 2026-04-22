I had deployed a STAC API to Azure and it was mostly working. The endpoints responded, the collections were registered, and most of the items I tried to post through the Transaction extension were being accepted. A few of them, though, came back with a 400 Bad Request, and the body of the response said only "Invalid request," without pointing at a field or including a schema path.

It took me three days to find the cause. When I found it, the fix was one line.

STAC items are required to have a `datetime` property. If an item doesn't represent a specific timestamp — if, for example, it stands for a monthly composite — the spec allows `datetime` to be `null` as long as you express the range with `start_datetime` and `end_datetime` instead. The validator is strict about the allowed values. It wants either a valid ISO 8601 string or the JSON value `null`, and nothing else.

My items, when they left my code and hit the network, had `{}`.

I had been building the items with pystac. The properties dict, though, was assembled upstream by a helper of mine that pulled fields out of a source record, and when the source didn't carry a concrete timestamp the helper left `datetime` as an empty dict rather than `None`. By the time that dict reached `pystac.Item(...)`, the empty object was already baked in. pystac is a structural library — it gives you the shape of a STAC object, but it does not validate your object against the STAC JSON Schema on construction. It held the `{}`, serialised through `to_dict()`, and `json.dumps` wrote it onto the wire without complaint.

The fix, once I understood where the `{}` was coming from, was to set `datetime` to `None` whenever I didn't have a concrete timestamp, and let pystac produce `null` in the output.

The three days are the interesting part, because the fix itself is trivial.

The validator that actually rejected my items was pgSTAC, and pgSTAC produces a specific and useful error in a case like this. It will tell you, in plain language, that `datetime` must be a string or null. By the time that rejection has travelled through the stac-fastapi layer, through the Azure container's web server, and back out to me, the message has been replaced by a generic 400. The specific error is generated, logged inside the validator, and then discarded before it ever reaches me.

So I was diffing JSON. I took one item that had posted cleanly and one that hadn't, laid them side by side, and compared them field by field. The difference, once I found it, was two characters.

What I should have done, and what I plan to do next time, is run pgSTAC's own validator locally against a candidate item before posting anything through the API. pgSTAC ships a CLI for this and it returns the answer in a second. I had the tool available the whole time. I just didn't use it, because I assumed the API would tell me what was wrong, and by the time I realised it wouldn't, I was already too committed to the diff to stop.

There's a more general pattern in this that I keep running into. The bugs that take the longest are rarely the intellectually difficult ones. They tend to be the ones where the layers between me and the actual failure point are opaque enough that I can't see through them. Each layer — the API gateway, the web framework, the container — is free to simplify an error on its way back, and most of them do by default. You end up debugging a summary of the problem rather than the problem, and the summary is usually too compressed to be diagnostic.

The practical move, before starting to diff or bisect, is to ask whether there's a more direct way to speak to the system. Sometimes that means running the spec-level validator locally. Sometimes it means dropping into a REPL and calling the underlying library by hand. Anything that removes a layer tends to move the useful error closer to you.

There's a smaller point here about pystac specifically. It's a good library and a pleasant one to build items with, but it is structural rather than validating. If you're producing items programmatically, you shouldn't treat pystac's willingness to accept your inputs as evidence that the server will accept them. Schema validation is a separate step, and it's something you have to choose to do — usually against `pystac.validation`, or against the spec's JSON Schema directly, or against pgSTAC's CLI before you ever hit the API.

The validator had the answer the whole time. I'd spent three days not asking it directly, because I trusted the layer closest to me to relay what the layer underneath it knew. It didn't. When a layer above a validator strips its errors down to generic codes, the cheapest fix is almost always to skip the wrapper and talk to the validator yourself, and it's something I now do before I start diffing inputs.

---

## TL;DR (LinkedIn)

I'm writing on LinkedIn for the sole purpose of learning to post more. I'll be writing some of the lessons I've learnt over the past year working with STAC. The lessons were messy, in a work log kind of way, but I learnt a lot. 

So I'd deployed a STAC API to Azure using Container Apps, for context, STAC is a ==**[SpatioTemporal Asset Catalog](https://www.google.com/search?client=safari&rls=en&q=SpatioTemporal+Asset+Catalog&ie=UTF-8&oe=UTF-8&sei=ln_jaefpG5WShbIPqPuGWA&dlnr=1&mstk=AUtExfC0646Oxo4r3dAq9pwCYFrOoD72Pa3rUIWw3bNHBoymGHhYcPXc-ZaObpxoMAHtaaMpXkM4VoEd8RpjTybdLanGMgNMdrbHdkLFnwEiyCe45e7ePYa7_Ky_Zgo7KEmmWXxbRWiM2uQdUhkjwhwdwoc8bJ0kydTBz9GLh9xxwWvD3snqKUD6BPl2t8Eoi699SOVZVC0P57G2NJCUZsstA80gB5vCcRQN8j9gJhPIInvrgVp7XFExY2Q5vhUA2zUeOojsQUx1F49oZZO-Lo12awFS&csui=3&ved=2ahUKEwj8k_bOufeTAxXEU0EAHS23OqYQgK4QegQIARAC)**== **(STAC)**, an open specification for organizing and searching geospatial data (satellite imagery, drones). It standardizes metadata for Earth observation, making data more interoperable and accessible. Most items I posted through the Transaction extension were accepted, but a few came back with a generic 400 Bad Request and a body that said only "Invalid request." Container logs offered nothing more.

Diffing a passing item against a failing one, I found the failing ones had `"datetime": {}` where the passing ones had `"datetime": null`. The STAC spec requires an ISO 8601 string or an explicit null for that field, so an empty object is rejected.

The `{}` came from a helper of mine that assembled the properties dict upstream of pystac — when there was no concrete timestamp, it left `datetime` as an empty dict rather than `None`. pystac is structural: it holds the shape of a STAC item without validating against the JSON Schema, so it carried the empty dict through `to_dict()` and `json.dumps` onto the wire.

The frustrating part is that pgSTAC, sitting below my API, knew the exact problem. Its validator would have told me `datetime` must be a string or null, but by the time the error travelled up through stac-fastapi and the Azure container, it had been flattened to a generic 400. pgSTAC's own validator CLI, run locally against a candidate item, would have returned the answer in a second.

That cost me three days. When a layer closer to you strips the underlying error to a useless code, you end up debugging the summary instead of the problem, and the productive move is to drop a layer and talk to whatever is actually doing the checking.
