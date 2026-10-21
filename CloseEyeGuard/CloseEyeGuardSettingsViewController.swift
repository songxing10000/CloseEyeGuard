//
//  CloseEyeGuardSettingsViewController.swift
//  CloseEyeGuard
//
//  Created by edy on 2026/10/21.
//

import UIKit

final class CloseEyeGuardSettingsViewController: UITableViewController {
    
    private enum Section: Int, CaseIterable {
        case monitor
        case voice
        case settings
    }
    
    private enum MonitorRow: Int, CaseIterable {
        case enabled
        case checkInterval
        case distanceThreshold
    }
    
    private enum VoiceRow: Int, CaseIterable {
        case enabled
        case volume
        case rate
        case text
    }
    
    private enum SettingsRow: Int, CaseIterable {
        case gesture
        case reset
    }
    
    private enum ReuseID {
        static let switchCell = "CloseEyeGuardSwitchCell"
        static let sliderCell = "CloseEyeGuardSliderCell"
        static let plain = "CloseEyeGuardPlainCell"
    }
    
    private let config = CloseEyeGuardConfig.shared
    
    init() {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "距离守护设置"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped))
        
        tableView.register(SwitchCell.self, forCellReuseIdentifier: ReuseID.switchCell)
        tableView.register(SliderCell.self, forCellReuseIdentifier: ReuseID.sliderCell)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 76
    }
    
    @objc private func closeTapped() {
        CloseEyeGuardSettingsPresenter.shared.hide()
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .monitor: return MonitorRow.allCases.count
        case .voice: return VoiceRow.allCases.count
        case .settings: return SettingsRow.allCases.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .monitor: return "监测"
        case .voice: return "语音提醒"
        case .settings: return "设置"
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .monitor: return "检测间隔越短响应越快，但越耗电"
        case .settings: return "在 App 任意界面四指双击可呼出/收起本面板"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .monitor:
            switch indexPath.row {
            case MonitorRow.enabled.rawValue:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseID.switchCell, for: indexPath) as! SwitchCell
                cell.configure(title: "启用监测", isOn: config.monitorEnabled) { [weak self] on in
                    self?.config.monitorEnabled = on
                }
                return cell
            case MonitorRow.checkInterval.rawValue:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseID.sliderCell, for: indexPath) as! SliderCell
                cell.configure(
                    title: "检测间隔",
                    value: config.checkInterval,
                    min: 0.5,
                    max: 10.0,
                    format: { String(format: "每 %.1f 秒", $0) }) { [weak self] value in
                    self?.config.checkInterval = value
                }
                return cell
            case MonitorRow.distanceThreshold.rawValue:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseID.sliderCell, for: indexPath) as! SliderCell
                cell.configure(
                    title: "报警阈值（人脸占画面宽度）",
                    value: config.faceWidthThreshold,
                    min: 0.10,
                    max: 0.50,
                    format: { String(format: "%.2f", $0) }) { [weak self] value in
                    self?.config.faceWidthThreshold = value
                }
                return cell
            default:
                return UITableViewCell()
            }
        case .voice:
            switch indexPath.row {
            case VoiceRow.enabled.rawValue:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseID.switchCell, for: indexPath) as! SwitchCell
                cell.configure(title: "语音提醒", isOn: config.voiceEnabled) { [weak self] on in
                    self?.config.voiceEnabled = on
                }
                return cell
            case VoiceRow.volume.rawValue:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseID.sliderCell, for: indexPath) as! SliderCell
                cell.configure(
                    title: "音量",
                    value: Double(config.volume),
                    min: 0.0,
                    max: 1.0,
                    format: { String(format: "%.0f%%", $0 * 100) }) { [weak self] value in
                    self?.config.volume = Float(value)
                }
                return cell
            case VoiceRow.rate.rawValue:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseID.sliderCell, for: indexPath) as! SliderCell
                cell.configure(
                    title: "语速",
                    value: Double(config.speechRate),
                    min: 0.0,
                    max: 1.0,
                    format: { String(format: "%.0f%%", $0 * 100) }) { [weak self] value in
                    self?.config.speechRate = Float(value)
                }
                return cell
            case VoiceRow.text.rawValue:
                let cell = (tableView.dequeueReusableCell(withIdentifier: ReuseID.plain)
                            ?? UITableViewCell(style: .value1, reuseIdentifier: ReuseID.plain))
                cell.textLabel?.text = "提醒文本"
                cell.detailTextLabel?.text = config.warningText
                cell.detailTextLabel?.textColor = .secondaryLabel
                cell.detailTextLabel?.adjustsFontSizeToFitWidth = true
                return cell
            default:
                return UITableViewCell()
            }
        case .settings:
            switch indexPath.row {
            case SettingsRow.gesture.rawValue:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseID.switchCell, for: indexPath) as! SwitchCell
                cell.configure(title: "四指双击呼出设置", isOn: config.settingsGestureEnabled) { [weak self] on in
                    self?.config.settingsGestureEnabled = on
                }
                return cell
            case SettingsRow.reset.rawValue:
                let cell = (tableView.dequeueReusableCell(withIdentifier: ReuseID.plain)
                            ?? UITableViewCell(style: .default, reuseIdentifier: ReuseID.plain))
                cell.textLabel?.text = "恢复默认设置"
                cell.textLabel?.textColor = .systemRed
                return cell
            default:
                return UITableViewCell()
            }
        }
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .monitor:
            break
        case .voice:
            if indexPath.row == VoiceRow.text.rawValue {
                presentTextEditor()
            }
        case .settings:
            if indexPath.row == SettingsRow.reset.rawValue {
                presentResetConfirmation()
            }
        }
    }
    
    // MARK: - 编辑
    
    private func presentTextEditor() {
        let alert = UIAlertController(title: "提醒文本", message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] field in
            field.text = self?.config.warningText
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self = self,
                  let text = alert.textFields?.first?.text,
                  !text.isEmpty else { return }
            self.config.warningText = text
            self.tableView.reloadData()
        })
        present(alert, animated: true)
    }
    
    private func presentResetConfirmation() {
        let alert = UIAlertController(
            title: "恢复默认设置",
            message: "所有配置将恢复出厂值",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "恢复", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.config.resetToDefaults()
            self.tableView.reloadData()
        })
        present(alert, animated: true)
    }
}

// MARK: - 单元格

private final class SwitchCell: UITableViewCell {
    private let toggle = UISwitch()
    private var onToggle: ((Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        toggle.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        accessoryView = toggle
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        textLabel?.text = title
        toggle.isOn = isOn
        self.onToggle = onToggle
    }
    
    @objc private func switchChanged(_ sender: UISwitch) {
        onToggle?(sender.isOn)
    }
}

private final class SliderCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = UISlider()
    private var format: ((Double) -> String)?
    private var onValueChange: ((Double) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        
        titleLabel.font = .systemFont(ofSize: 15)
        valueLabel.font = .systemFont(ofSize: 13)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right
        slider.minimumTrackTintColor = .systemBlue
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(slider)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 11),
            valueLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -8),
            slider.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: valueLabel.trailingAnchor),
            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            slider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -11),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(title: String,
                   value: Double,
                   min: Double,
                   max: Double,
                   format: @escaping (Double) -> String,
                   onValueChange: @escaping (Double) -> Void) {
        titleLabel.text = title
        valueLabel.text = format(value)
        slider.minimumValue = Float(min)
        slider.maximumValue = Float(max)
        slider.value = Float(value)
        self.format = format
        self.onValueChange = onValueChange
    }
    
    @objc private func sliderValueChanged(_ sender: UISlider) {
        let value = Double(sender.value)
        valueLabel.text = format?(value)
        onValueChange?(value)
    }
}
