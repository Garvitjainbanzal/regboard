import UIKit

/// In-keyboard emoji picker. Original implementation; not the system emoji keyboard (no skin tones, search or Genmoji).
final class EmojiPanel: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onPick: ((String) -> Void)?
    var onBack: (() -> Void)?
    var onDelete: (() -> Void)?
    var palette: ThemePalette = .dark { didSet { restyle() } }
    var recents = RecentEmojiStore()

    private var sections: [EmojiCategory] = []
    private let collection: UICollectionView
    private let bar = UIStackView()
    private var tabButtons: [UIButton] = []
    private let backButton = UIButton(type: .system), deleteButton = UIButton(type: .system)

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 44, height: 44); layout.minimumInteritemSpacing = 2; layout.minimumLineSpacing = 2
        layout.headerReferenceSize = CGSize(width: 0, height: 24)
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        collection.dataSource = self; collection.delegate = self
        collection.register(EmojiCell.self, forCellWithReuseIdentifier: "c")
        collection.register(EmojiHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "h")
        collection.backgroundColor = .clear
        addSubview(collection)
        backButton.setTitle("ABC", for: .normal); backButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        backButton.accessibilityLabel = "Back to letters"
        deleteButton.setTitle("⌫", for: .normal); deleteButton.addTarget(self, action: #selector(del), for: .touchUpInside)
        deleteButton.accessibilityLabel = "Delete"
        bar.axis = .horizontal; bar.distribution = .fillEqually
        addSubview(bar)
        reload(); restyle()
    }
    required init?(coder: NSCoder) { fatalError() }

    func reload() {
        var s = EmojiData.categories
        let r = recents.recents
        if !r.isEmpty { s.insert(EmojiCategory(id: "recent", icon: "🕘", name: "Frequently used", emoji: r), at: 0) }
        sections = s
        tabButtons.forEach { $0.removeFromSuperview() }
        bar.arrangedSubviews.forEach { bar.removeArrangedSubview($0); $0.removeFromSuperview() }
        bar.addArrangedSubview(backButton)
        tabButtons = sections.enumerated().map { i, c in
            let b = UIButton(type: .system); b.setTitle(c.icon, for: .normal); b.tag = i
            b.accessibilityLabel = c.name; b.addTarget(self, action: #selector(tab(_:)), for: .touchUpInside); return b
        }
        tabButtons.forEach(bar.addArrangedSubview); bar.addArrangedSubview(deleteButton)
        collection.reloadData(); restyle()
    }
    private func restyle() {
        backgroundColor = palette.background.ui
        backButton.setTitleColor(palette.keyText.ui, for: .normal); deleteButton.setTitleColor(palette.keyText.ui, for: .normal)
    }
    @objc private func back() { onBack?() }
    @objc private func del() { onDelete?() }
    @objc private func tab(_ b: UIButton) {
        collection.setContentOffset(CGPoint(x: 0, y: collection.layoutAttributesForSupplementaryElement(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: b.tag))?.frame.minY ?? 0), animated: true)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        bar.frame = CGRect(x: 0, y: bounds.height - 40, width: bounds.width, height: 40)
        collection.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - 40)
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int { sections[section].emoji.count }
    func collectionView(_ cv: UICollectionView, cellForItemAt i: IndexPath) -> UICollectionViewCell {
        let c = cv.dequeueReusableCell(withReuseIdentifier: "c", for: i) as! EmojiCell
        c.label.text = sections[i.section].emoji[i.item]; c.isAccessibilityElement = true; c.accessibilityLabel = c.label.text; return c
    }
    func collectionView(_ cv: UICollectionView, viewForSupplementaryElementOfKind kind: String, at i: IndexPath) -> UICollectionReusableView {
        let h = cv.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "h", for: i) as! EmojiHeader
        h.label.text = sections[i.section].name.uppercased(); h.label.textColor = palette.candidateText.ui; return h
    }
    func collectionView(_ cv: UICollectionView, didSelectItemAt i: IndexPath) {
        let e = sections[i.section].emoji[i.item]
        recents.record(e); onPick?(e)
    }
}

final class EmojiCell: UICollectionViewCell {
    let label = UILabel()
    override init(frame: CGRect) { super.init(frame: frame); label.font = .systemFont(ofSize: 30); label.textAlignment = .center; contentView.addSubview(label) }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews(); label.frame = contentView.bounds }
}
final class EmojiHeader: UICollectionReusableView {
    let label = UILabel()
    override init(frame: CGRect) { super.init(frame: frame); label.font = .systemFont(ofSize: 11, weight: .semibold); addSubview(label) }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews(); label.frame = bounds.insetBy(dx: 8, dy: 0) }
}
