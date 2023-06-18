import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import AvatarNode
import AccountContext
import MessageInputPanelComponent
import BundleIconComponent

private final class AvatarComponent: Component {
    let context: AccountContext
    let peer: EnginePeer

    init(context: AccountContext, peer: EnginePeer) {
        self.context = context
        self.peer = peer
    }

    static func ==(lhs: AvatarComponent, rhs: AvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatarNode: AvatarNode
        
        private var component: AvatarComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 18.0))
            
            super.init(frame: frame)
            
            self.addSubnode(self.avatarNode)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: 36.0, height: 36.0)

            self.avatarNode.frame = CGRect(origin: CGPoint(), size: size)
            self.avatarNode.setPeer(
                context: component.context,
                theme: component.context.sharedContext.currentPresentationData.with({ $0 }).theme,
                peer: component.peer,
                synchronousLoad: true
            )
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}


final class StoryPreviewComponent: Component {
    typealias EnvironmentType = Empty
    
    let context: AccountContext
    let caption: String
    
    init(
        context: AccountContext,
        caption: String
    ) {
        self.context = context
        self.caption = caption
    }
    
    static func ==(lhs: StoryPreviewComponent, rhs: StoryPreviewComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.caption != rhs.caption {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private var peerDisposable: Disposable?
        fileprivate var accountPeer: EnginePeer?
        
        init(context: AccountContext) {
            self.context = context
            
            super.init()
            
            self.peerDisposable = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                if let self {
                    self.accountPeer = peer
                    self.updated()
                }
            })
        }
        
        deinit {
            self.peerDisposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(
            context: self.context
        )
    }
    
    public final class View: UIView {
        private let line = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let avatar = ComponentView<Empty>()
        private let cancelButton = ComponentView<Empty>()
        private let inputPanel = ComponentView<Empty>()
        private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
        
        private let scrubber = ComponentView<Empty>()
        
        private var component: StoryPreviewComponent?
        private weak var state: State?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundColor = .clear
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StoryPreviewComponent, availableSize: CGSize, state: State, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let lineSize = self.line.update(
                transition: transition,
                component: AnyComponent(Rectangle(color: UIColor(white: 1.0, alpha: 0.5))),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 8.0 * 2.0, height: 2.0)
            )
            let lineFrame = CGRect(
                origin: CGPoint(x: 8.0, y: 8.0),
                size: lineSize
            )
            if let lineView = self.line.view {
                if lineView.superview == nil {
                    lineView.layer.cornerRadius = 1.0
                    self.addSubview(lineView)
                }
                transition.setPosition(view: lineView, position: lineFrame.center)
                transition.setBounds(view: lineView, bounds: CGRect(origin: .zero, size: lineFrame.size))
            }
                        
            let cancelButtonSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(BundleIconComponent(
                    name: "Media Gallery/Close",
                    tintColor: UIColor.white
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            let cancelButtonFrame = CGRect(
                origin: CGPoint(x: 17.0, y: 24.0),
                size: cancelButtonSize
            )
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                }
                transition.setPosition(view: cancelButtonView, position: cancelButtonFrame.center)
                transition.setBounds(view: cancelButtonView, bounds: CGRect(origin: .zero, size: cancelButtonFrame.size))
            }
            
            if let accountPeer = state.accountPeer {
                let avatarSize = self.avatar.update(
                    transition: transition,
                    component: AnyComponent(AvatarComponent(
                        context: component.context,
                        peer: accountPeer
                    )),
                    environment: {},
                    containerSize: CGSize(width: 44.0, height: 44.0)
                )
                let avatarFrame = CGRect(
                    origin: CGPoint(x: availableSize.width - avatarSize.width - 6.0, y: 14.0),
                    size: avatarSize
                )
                if let avatarView = self.avatar.view {
                    if avatarView.superview == nil {
                        self.addSubview(avatarView)
                    }
                    transition.setPosition(view: avatarView, position: avatarFrame.center)
                    transition.setBounds(view: avatarView, bounds: CGRect(origin: .zero, size: avatarFrame.size))
                }
            }
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(Text(
                    text: "My story",
                    font: Font.semibold(17.0),
                    color: .white
                )),
                environment: {},
                containerSize: CGSize(width: 180.0, height: 44.0)
            )
            let titleFrame = CGRect(
                origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: 21.0),
                size: titleSize
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                transition.setBounds(view: titleView, bounds: CGRect(origin: .zero, size: titleFrame.size))
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let inputPanelSize = self.inputPanel.update(
                transition: transition,
                component: AnyComponent(MessageInputPanelComponent(
                    externalState: self.inputPanelExternalState,
                    context: component.context,
                    theme: presentationData.theme,
                    strings: presentationData.strings,
                    style: .story,
                    placeholder: "Reply Privately...",
                    alwaysDarkWhenHasText: false,
                    areVoiceMessagesAvailable: false,
                    presentController: { _ in
                    },
                    sendMessageAction: {
                    },
                    setMediaRecordingActive: { _, _, _ in },
                    lockMediaRecording: nil,
                    stopAndPreviewMediaRecording: nil,
                    discardMediaRecordingPreview: nil,
                    attachmentAction: { },
                    timeoutAction: nil,
                    forwardAction: nil,
                    presentVoiceMessagesUnavailableTooltip: nil,
                    audioRecorder: nil,
                    videoRecordingStatus: nil,
                    isRecordingLocked: false,
                    recordedAudioPreview: nil,
                    wasRecordingDismissed: false,
                    timeoutValue: nil,
                    timeoutSelected: false,
                    displayGradient: false,
                    bottomInset: 0.0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 200.0)
            )
            
            let inputPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - inputPanelSize.height - 3.0), size: inputPanelSize)
            if let inputPanelView = self.inputPanel.view {
                if inputPanelView.superview == nil {
                    self.addSubview(inputPanelView)
                }
                transition.setFrame(view: inputPanelView, frame: inputPanelFrame)
            }
           
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
