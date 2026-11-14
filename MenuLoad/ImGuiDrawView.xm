#include "Includes.h"
#include "UserMenu.h"
#include "../Font.h"
#include "../Source/BasicHacks.h"

@interface ImGuiDrawView () <MTKViewDelegate>

@property (nonatomic, strong) id <MTLDevice> device;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;

@end

@implementation ImGuiDrawView

static bool MenDeal = true;

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];

    if (!self.device) abort();

    BasicCheats.Initialize();

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;

    ImGui::StyleColorsClassic();

    io.Fonts->Clear();

    ImFontConfig config;
    config.FontDataOwnedByAtlas = false;
    Font = io.Fonts->AddFontFromMemoryCompressedBase85TTF(CurvyBase85, 40.f, &config, io.Fonts->GetGlyphRangesChineseFull());

    ImGui_ImplMetal_Init(_device);
    
    

    return self;
}

+ (void)showChange:(BOOL)open
{
    MenDeal = open;
}

+ (BOOL)isMenuShowing {
    return MenDeal;
}

- (MTKView *)mtkView
{
    return (MTKView *)self.view;
}

- (void)loadView
{
    CGFloat w = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.width;
    CGFloat h = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.height;
    self.view = [[MTKView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.mtkView.device = self.device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    self.mtkView.clipsToBounds = YES;
}

- (void)updateIOWithTouchEvent:(UIEvent *)event
{
    UITouch *anyTouch = event.allTouches.anyObject;
    CGPoint touchLocation = [anyTouch locationInView:self.view];
    ImGuiIO &io = ImGui::GetIO();
    io.MousePos = ImVec2(touchLocation.x, touchLocation.y);

    BOOL hasActiveTouch = NO;
    for (UITouch *touch in event.allTouches)
    {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled)
        {
            hasActiveTouch = YES;
            break;
        }
    }
    io.MouseDown[0] = hasActiveTouch;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)drawInMTKView:(MTKView*)view
{
    hideRecordTextfield.secureTextEntry = KTempVars.StreamerMode; //imgui streamer mode

    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;

    CGFloat framebufferScale = view.window.screen.nativeScale ? : UIScreen.mainScreen.nativeScale;
    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);
    io.DeltaTime = 1 / float(view.preferredFramesPerSecond ? : 60);

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

    if (MenDeal) {
        [self.view setUserInteractionEnabled:YES];
        [self.view.superview setUserInteractionEnabled:YES];
        [menuTouchView setUserInteractionEnabled:YES];
    }
    else {
        [self.view setUserInteractionEnabled:NO];
        [self.view.superview setUserInteractionEnabled:NO];
        [menuTouchView setUserInteractionEnabled:NO];
    }
    
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil)
    {
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder pushDebugGroup:@"Dear ImGui Rendering"];

        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui::NewFrame();

        // --- ESP START ---
        auto WorldToScreen = [](Vector3 pos, ImVec2& screen, float* matrix, int width, int height) -> bool {
            float w = matrix[3] * pos.x + matrix[7] * pos.y + matrix[11] * pos.z + matrix[15];
            if (w < 0.01f) return false;
            float x = matrix[0] * pos.x + matrix[4] * pos.y + matrix[8] * pos.z + matrix[12];
            float y = matrix[1] * pos.x + matrix[5] * pos.y + matrix[9] * pos.z + matrix[13];
            screen.x = (width / 2.0f) + (width / 2.0f) * x / w;
            screen.y = (height / 2.0f) - (height / 2.0f) * y / w;
            return true;
        };

        ImDrawList* draw_list = ImGui::GetBackgroundDrawList();
        ImVec2 screenSize = ImGui::GetIO().DisplaySize;

        for (auto& pos : enemyPositions) {
            ImVec2 screenPos;
            if (WorldToScreen(pos, screenPos, viewMatrix, (int)screenSize.x, (int)screenSize.y)) {
                draw_list->AddRect(
                    ImVec2(screenPos.x - 25, screenPos.y - 50),
                    ImVec2(screenPos.x + 25, screenPos.y + 10),
                    IM_COL32(255, 0, 0, 255), 0.0f, 0, 2.0f
                );
            }
        }
        // --- ESP END ---

        std::string debugStr = "ESP Enemies: " + std::to_string(enemyPositions.size());
        ImFont* font = ImGui::GetFont();
        font->Scale = 12.f / font->FontSize;
        
        if (MenDeal)
            Menu.Initialize();  // Initialize menu only if it's open

        // Call RenderingMenu to render the menu regardless of MenDeal status
        UserMenu::GetInstance().RenderingMenu();


        ImGui::Render();
        ImDrawData* draw_data = ImGui::GetDrawData();
        ImGui_ImplMetal_RenderDrawData(draw_data, commandBuffer, renderEncoder);

        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];

        [commandBuffer presentDrawable:view.currentDrawable];
    }
    [commandBuffer commit];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size
{
    
}

@end


%ctor
{
    // Initialization logic if necessary
}
