#include "linediffer.h"

#include <QHash>
#include <QStringList>
#include <QVector>
#include <algorithm>

namespace {

    // Give up (and mark the differing region as modified) if the two texts differ
    // by more than this many line edits. Keeps memory and time bounded.
    constexpr int kMaxEditDistance = 2000;

    // Myers O(ND) diff. a = old lines, b = new lines (as integer ids).
    // ops (forward order): 'E' equal, 'I' line inserted from b, 'D' line deleted from a.
    // Returns false if the edit distance exceeds kMaxEditDistance.
    bool myers(const QVector<int> &a, const QVector<int> &b, QVector<char> &ops)
    {
        const int N = a.size();
        const int M = b.size();
        const int maxD = std::min(N + M, kMaxEditDistance);
        const int off = maxD + 1;

        QVector<int> v(2 * maxD + 3, 0);
        QVector<QVector<int>> trace;
        bool found = false;
        int finalD = 0;

        for (int d = 0; d <= maxD && !found; ++d) {
            // Snapshot of v for diagonals [-d, d] before this round
            QVector<int> snap(2 * d + 1);
            for (int k = -d; k <= d; ++k)
                snap[k + d] = v[k + off];
            trace.push_back(snap);

            for (int k = -d; k <= d; k += 2) {
                int x;
                if (k == -d || (k != d && v[k - 1 + off] < v[k + 1 + off]))
                    x = v[k + 1 + off];
                else
                    x = v[k - 1 + off] + 1;
                int y = x - k;
                while (x < N && y < M && a[x] == b[y]) {
                    ++x;
                    ++y;
                }
                v[k + off] = x;
                if (x >= N && y >= M) {
                    found = true;
                    finalD = d;
                    break;
                }
            }
        }

        if (!found)
            return false;

        QVector<char> rev;
        int x = N;
        int y = M;
        for (int d = finalD; d >= 0; --d) {
            const QVector<int> &vs = trace[d];
            auto at = [&vs, d](int k) { return vs[k + d]; };

            if (d == 0) {
                while (x > 0 && y > 0) {
                    --x;
                    --y;
                    rev.push_back('E');
                }
                break;
            }

            const int k = x - y;
            int prevK;
            if (k == -d || (k != d && at(k - 1) < at(k + 1)))
                prevK = k + 1;
            else
                prevK = k - 1;

            const int prevX = at(prevK);
            const int prevY = prevX - prevK;

            while (x > prevX && y > prevY) {
                --x;
                --y;
                rev.push_back('E');
            }
            rev.push_back(x == prevX ? 'I' : 'D');
            x = prevX;
            y = prevY;
        }

        ops.clear();
        ops.reserve(rev.size());
        for (int i = rev.size() - 1; i >= 0; --i)
            ops.push_back(rev[i]);
        return true;
    }

} // namespace

LineDiffer::LineDiffer(QObject *parent)
: QObject(parent)
{
}

QVariantList LineDiffer::diff(const QString &disk, const QString &current) const
{
    const QStringList a = disk.split(QLatin1Char('\n'));
    const QStringList b = current.split(QLatin1Char('\n'));
    const int M = b.size();
    QVector<int> states(M, 0);

    // Trim common prefix / suffix: most edits are small, so this keeps the diff tiny
    int prefix = 0;
    while (prefix < a.size() && prefix < M && a[prefix] == b[prefix])
        ++prefix;

    int suffix = 0;
    while (suffix < a.size() - prefix && suffix < M - prefix
        && a[a.size() - 1 - suffix] == b[M - 1 - suffix])
        ++suffix;

    const int aMid = a.size() - prefix - suffix;
    const int bMid = M - prefix - suffix;

    if (aMid > 0 || bMid > 0) {
        QHash<QString, int> ids;
        auto idOf = [&ids](const QString &s) -> int {
            auto it = ids.constFind(s);
            if (it != ids.constEnd())
                return it.value();
            const int n = ids.size();
            ids.insert(s, n);
            return n;
        };

        QVector<int> ai;
        QVector<int> bi;
        ai.reserve(aMid);
        bi.reserve(bMid);
        for (int i = 0; i < aMid; ++i) ai.push_back(idOf(a[prefix + i]));
        for (int i = 0; i < bMid; ++i) bi.push_back(idOf(b[prefix + i]));

        QVector<char> ops;
        if (myers(ai, bi, ops)) {
            int bPos = prefix;
            for (char op : std::as_const(ops)) {
                if (op == 'E') {
                    ++bPos;
                } else if (op == 'I') {
                    states[bPos] = 1;   // modified or newly added line: same marker
                    ++bPos;
                }
            }
        } else {
            for (int i = 0; i < bMid; ++i)
                states[prefix + i] = 1;
        }
    }

    QVariantList result;
    result.reserve(M);
    for (int s : std::as_const(states))
        result.append(s);
    return result;
}
