.pragma library

// Ranking for the Deck launcher, kept pure so it can be read (and tested)
// without the shell. Lower rank is better; -1 means "no match".
//
//   0  the name starts with the query            "fir" -> Firefox
//   1  a word in the name starts with it         "code" -> Visual Studio Code
//   2  the name contains it                      "fox" -> Firefox
//   3  its letters appear in order in the name   "vsc" -> Visual Studio Code
//   4  generic name, keywords or comment hit     "browser" -> Firefox

function text(value) {
    return typeof value === "string" ? value.toLowerCase() : "";
}

function list(value) {
    var out = [];
    if (value === null || value === undefined || typeof value.length !== "number" || typeof value === "string")
        return out;
    for (var i = 0; i < value.length && i < 64; i++)
        if (typeof value[i] === "string")
            out.push(value[i].toLowerCase());
    return out;
}

function subsequence(haystack, needle) {
    var j = 0;
    for (var i = 0; i < haystack.length && j < needle.length; i++)
        if (haystack.charAt(i) === needle.charAt(j))
            j++;
    return j === needle.length;
}

function rank(entry, query) {
    var q = text(query).trim();
    if (q.length === 0)
        return 0;
    var name = text(entry.name);
    if (name.indexOf(q) === 0)
        return 0;
    var words = name.split(/[\s\-_.]+/);
    for (var i = 0; i < words.length; i++)
        if (words[i].indexOf(q) === 0)
            return 1;
    if (name.indexOf(q) >= 0)
        return 2;
    if (q.length >= 2 && subsequence(name, q))
        return 3;
    if (text(entry.genericName).indexOf(q) >= 0 || text(entry.comment).indexOf(q) >= 0)
        return 4;
    var keys = list(entry.keywords);
    for (var k = 0; k < keys.length; k++)
        if (keys[k].indexOf(q) >= 0)
            return 4;
    return -1;
}

// A clean list of non-empty strings from whatever launcher.json holds.
function ids(value) {
    var out = [];
    if (value === null || value === undefined || typeof value === "string" || typeof value.length !== "number")
        return out;
    for (var i = 0; i < value.length && i < 2000; i++)
        if (typeof value[i] === "string" && value[i].trim().length > 0)
            out.push(value[i].trim());
    return out;
}

// apps: desktop entries; pinned/recent: ordered id lists; hidden: id list.
function results(apps, query, pinned, recent, hidden) {
    var hide = {}, pin = {}, seen = {};
    var h = ids(hidden), p = ids(pinned), r = ids(recent);
    for (var a = 0; a < h.length; a++) hide[h[a]] = true;
    for (var b = 0; b < p.length; b++) pin[p[b]] = b;
    var rec = {};
    for (var c = 0; c < r.length; c++) rec[r[c]] = c;

    var rows = [];
    for (var i = 0; i < apps.length; i++) {
        var e = apps[i];
        if (!e || e.noDisplay)
            continue;
        var id = String(e.id || "");
        if (hide[id] === true || seen[id] === true)
            continue;
        seen[id] = true;
        var score = rank(e, query);
        if (score < 0)
            continue;
        rows.push({
            entry: e,
            score: score,
            pinned: pin[id] !== undefined ? pin[id] : 9999,
            recent: rec[id] !== undefined ? rec[id] : 9999,
            name: text(e.name)
        });
    }
    rows.sort(function (x, y) {
        if (x.score !== y.score) return x.score - y.score;
        if (x.pinned !== y.pinned) return x.pinned - y.pinned;
        if (x.recent !== y.recent) return x.recent - y.recent;
        return x.name < y.name ? -1 : (x.name > y.name ? 1 : 0);
    });
    var out = [];
    for (var j = 0; j < rows.length; j++)
        out.push({ entry: rows[j].entry, pinned: rows[j].pinned !== 9999 });
    return out;
}
