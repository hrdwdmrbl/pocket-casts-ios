import UIKit
import SafariServices

extension ChaptersViewController: UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {
    private static let chapterCell = "ChapterCell"

    func registerCells() {
        chaptersTable.register(UINib(nibName: "PlayerChapterCell", bundle: nil), forCellReuseIdentifier: Self.chapterCell)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollViewHandler?.scrollViewDidScroll?(scrollView)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        playbackManager.chapterCount()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.chapterCell, for: indexPath) as! PlayerChapterCell
        let chapter = playbackManager.chapterAt(index: indexPath.row)!
        let current = playbackManager.currentChapters()
        let state: PlayerChapterCell.ChapterPlayState
        if chapter.index == current.index {
            state = playbackManager.isPlaying ? .currentlyPlaying : .currentlyPaused
        } else {
            state = chapter.index > current.index ? .future : .played
        }
        cell.populateFrom(chapter: chapter, playState: state) { [weak self] url in
            if Settings.openLinks {
                UIApplication.shared.open(url)
            } else {
                self?.present(SFSafariViewController(url: url), animated: true)
            }
        }
        cell.seperatorView.isHidden = chapter.index == current.index - 1 || chapter.index == current.index || indexPath.row == playbackManager.chapterCount() - 1
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let chapter = playbackManager.chapterAt(index: indexPath.row)!
        if chapter.index == playbackManager.currentChapters().index {
            containerDelegate?.scrollToNowPlaying()
        } else {
            playbackManager.skipToChapter(chapter, startPlaybackAfterSkip: true)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}
