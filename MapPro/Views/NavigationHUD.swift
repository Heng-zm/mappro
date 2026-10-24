import SwiftUI

/// Google Maps-style in-app guidance banner with live maneuver, ETA and speed.
struct NavigationHUD: View {
    @ObservedObject var engine: MapEngine
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBanner
            Spacer(minLength: 0)
            bottomBar
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: engine.navigationStepIndex)
        .animation(.easeInOut(duration: 0.25), value: engine.navigationInstruction)
    }

    private var topBanner: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(AppTheme.blue)
                    Image(systemName: engine.navigationManeuverSymbol)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(engine.navigationDistanceToManeuverText)
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(engine.navigationStepProgressText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(engine.navigationInstruction)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 2)

                Button {
                    engine.toggleVoiceGuidance()
                } label: {
                    Image(systemName: engine.voiceGuidanceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(engine.voiceGuidanceEnabled ? AppTheme.blue : Color.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(engine.voiceGuidanceEnabled ? "Mute voice guidance" : "Unmute voice guidance")

                Button(action: onEnd) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End navigation")
            }

            if let next = engine.navigationNextInstruction {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Then \(next)")
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.secondary)
                .padding(.leading, 60)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 20, y: 8)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.navigationRemainingTimeText)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("\(engine.navigationRemainingDistanceText) · Arrive \(engine.navigationArrivalText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            speedBadge

            Button(action: onEnd) {
                Text("End")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 17)
                    .padding(.vertical, 11)
                    .background(AppTheme.red, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End navigation")
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 20, y: 8)
    }

    private var speedBadge: some View {
        VStack(spacing: 0) {
            Text("\(Int(engine.speedKPH.rounded()))")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text("km/h")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 56, height: 48)
        .background(
            Color.primary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityLabel("Speed \(Int(engine.speedKPH.rounded())) kilometers per hour")
    }
}
