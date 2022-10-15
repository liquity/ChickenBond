// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./CommonData.sol";
import "./ChickenOutData.sol";

contract ChickenOutAnimations {
    function getSVGAnimations(CommonData calldata _commonData) external pure returns (bytes memory) {
        string[4][9] memory p = [
            ['404.7', '414.6', '424.5', '434.4'],
            ['542.9', '531.3', '519.8', '508.2'],
            ['338.7', '326.6', '314.5', '302.4'],
            ['542.9', '531.3', '519.8', '508.2'],
            ['375', '375', '375', '375'],
            ['616.1', '629', '641.9', '654.7'],
            ['58.1', '77.4', '96.8', '116.2'],
            ['79.2', '105.6', '132', '158.4'],
            ['-79.2', '-105.6', '-132', '-158.4']
        ];

        return abi.encodePacked(
            abi.encodePacked(
                '#co-chicken-',
                _commonData.tokenIDString,
                ' .co-chicken g,#co-chicken-',
                _commonData.tokenIDString,
                ' .co-chicken path,#co-chicken-',
                _commonData.tokenIDString,
                ' .co-chicken circle{animation:co-run 0.3s infinite ease-in-out alternate;}#co-chicken-',
                _commonData.tokenIDString,
                ' .co-left-leg path{animation:co-left-leg 0.3s infinite ease-in-out alternate;transform-origin:',
                p[0][uint256(_commonData.size)],
                'px ',
                p[1][uint256(_commonData.size)],
                'px;}#co-chicken-'
            ),
            abi.encodePacked(
                _commonData.tokenIDString,
                ' .co-right-leg path{animation:co-right-leg 0.3s infinite ease-in-out alternate;transform-origin:',
                p[2][uint256(_commonData.size)],
                'px ',
                p[3][uint256(_commonData.size)],
                'px;}#co-chicken-',
                _commonData.tokenIDString,
                ' .co-shadow{animation:co-shadow 0.3s infinite ease-in-out alternate;transform-origin:',
                p[4][uint256(_commonData.size)],
                'px ',
                p[5][uint256(_commonData.size)],
                'px;}@keyframes co-run{10%{transform:translateY(0);}100%{transform:translateY(',
                p[6][uint256(_commonData.size)]
            ),
            abi.encodePacked(
                'px);}}@keyframes co-left-leg{20%{transform:rotate(-0deg);}100%{transform:rotate(-75deg)translateX(',
                p[7][uint256(_commonData.size)],
                'px);}}@keyframes co-right-leg{0%{transform:rotate(5deg);}20%{transform:rotate(5deg);}100%{transform:rotate(70deg)translateX(',
                p[8][uint256(_commonData.size)],
                'px);}}@keyframes co-shadow{0%{transform:scale(60%);}100%{transform:scale(100%);}}'
            )
        );
    }
}

contract ChickenOutShadow {
    function getSVGShadow(CommonData calldata _commonData) external pure returns (bytes memory) {
        string[4][1] memory p = [
            ['cx="372.4" cy="616.1" rx="48.2" ry="7.3"', 'cx="371.5" cy="629" rx="64.2" ry="9.7"', 'cx="370.6" cy="641.9" rx="80.3" ry="12.1"', 'cx="369.7" cy="654.7" rx="96.4" ry="14.5"']
        ];

        return abi.encodePacked(
            '<ellipse class="co-shadow" style="fill:#000;mix-blend-mode:overlay" ',
            p[0][uint256(_commonData.size)],
            '/>'
        );
    }
}

contract ChickenOutLeftLeg {
    function getSVGLeftLeg(CommonData calldata _commonData) external pure returns (bytes memory) {
        string[4][2] memory p = [
            ['M318.3 547.7c-1.3 0.5-2.8 0.1-3.3-1.1s0.3-2.5 1.6-3l23.3-9.4c1.3-0.5 2.8-0.1 3.3 1.1s-0.3 2.5-1.6 3Z', 'M299.4 537.7c-1.8 0.7-3.8 0.1-4.4-1.4s0.4-3.3 2.2-4.1l31-12.4c1.8-0.7 3.8-0.1 4.4 1.4s-0.4 3.3-2.1 4Z', 'M280.5 527.8c-2.2 0.9-4.7 0.1-5.5-1.8s0.5-4.2 2.7-5.1l38.8-15.5c2.2-0.9 4.7-0.1 5.5 1.7s-0.5 4.2-2.7 5.1Z', 'M261.6 517.8c-2.6 1.1-5.6 0.1-6.6-2.1s0.6-5 3.3-6.1l46.5-18.7c2.6-1.1 5.6-0.1 6.6 2.2s-0.6 5-3.2 6Z'],
            ['M314.4 540.2l5.3 2.1a0.6 0.6 0 0 1 0.3 0.3l0.8 2.1a10.7 10.7 0 0 1 0.5 5l-0.9 4.9c-0.2 1.2-1.7 1.2-2.1 0l-5.2-12.8C312.6 540.4 313.2 539.7 314.4 540.2Z', 'M294.3 527.8l6.9 2.8a0.7 0.7 0 0 1 0.4 0.3l1.1 2.8a14.3 14.3 0 0 1 0.7 6.8l-1.2 6.5c-0.3 1.5-2.2 1.6-2.9 0l-6.8-17.1C291.7 528 292.5 527.1 294.3 527.8Z', 'M274.1 515.4l8.7 3.4a0.9 0.9 0 0 1 0.5 0.5l1.4 3.5a17.9 17.9 0 0 1 0.8 8.4l-1.5 8.1c-0.4 1.9-2.8 2-3.6 0.1l-8.5-21.4C270.9 515.7 271.9 514.5 274.1 515.4Z', 'M253.9 502.9l10.5 4.2a1.1 1.1 0 0 1 0.5 0.6l1.7 4.1a21.5 21.5 0 0 1 1 10.1l-1.8 9.8c-0.4 2.3-3.4 2.4-4.3 0.1l-10.3-25.7C250.1 503.3 251.3 501.9 253.9 502.9Z']
        ];

        return abi.encodePacked(
            '<g class="co-left-leg"><path style="fill:#352d20" d="',
            p[0][uint256(_commonData.size)],
            '"/><path style="fill:#352d20" d="',
            p[1][uint256(_commonData.size)],
            '"/></g>'
        );
    }
}

contract ChickenOutRightLeg {
    function getSVGRightLeg(CommonData calldata _commonData) external pure returns (bytes memory) {
        string[4][2] memory p = [
            ['M422.8 548.7c1.1 0.9 1.4 2.5 0.6 3.4s-2.3 0.9-3.4 0l-19.2-16.1c-1.1-0.9-1.4-2.5-0.6-3.4s2.3-0.9 3.4 0Z', 'M438.8 539.1c1.5 1.2 1.8 3.3 0.8 4.5s-3.1 1.2-4.6 0l-25.6-21.5c-1.5-1.2-1.8-3.3-0.8-4.5s3.1-1.2 4.5 0Z', 'M454.7 529.5c1.9 1.6 2.3 4.1 1 5.6s-3.9 1.6-5.7 0l-32-26.8c-1.8-1.6-2.3-4.1-1-5.7s3.9-1.6 5.7 0Z', 'M470.7 519.9c2.2 1.9 2.8 4.9 1.2 6.7s-4.7 1.9-6.9 0l-38.5-32.2c-2.2-1.9-2.8-4.9-1.2-6.8s4.7-1.9 6.9 0Z'],
            ['M418.1 555.6l-0.7-5.6a0.5 0.5 0 0 1 0.2-0.4l1.4-1.7a10.8 10.8 0 0 1 4.2-2.8l4.7-1.5c1.1-0.4 1.8 0.9 1.1 1.8l-8.9 10.6C419.2 557.2 418.2 557 418.1 555.6Z', 'M432.4 548.3l-0.8-7.4a0.7 0.7 0 0 1 0.1-0.6l2-2.3a14.4 14.4 0 0 1 5.6-3.7l6.3-2c1.5-0.5 2.5 1.2 1.4 2.5l-11.9 14C433.9 550.4 432.6 550.2 432.4 548.3Z', 'M446.8 541l-1.1-9.3a0.9 0.9 0 0 1 0.2-0.7l2.4-2.8a17.9 17.9 0 0 1 7-4.7l7.9-2.6c1.9-0.6 3.1 1.5 1.8 3.2l-14.8 17.6C448.6 543.6 447.1 543.3 446.8 541Z', 'M461.2 533.8l-1.4-11.3a1.1 1.1 0 0 1 0.3-0.7l2.9-3.5a21.5 21.5 0 0 1 8.4-5.6l9.5-3.1c2.3-0.7 3.7 1.8 2.1 3.8l-17.8 21.1C463.3 536.9 461.5 536.5 461.2 533.8Z']
        ];

        return abi.encodePacked(
            '<g class="co-right-leg"><path style="fill:#352d20" d="',
            p[0][uint256(_commonData.size)],
            '"/><path style="fill:#352d20" d="',
            p[1][uint256(_commonData.size)],
            '"/></g>'
        );
    }
}

contract ChickenOutBeak {
    function getSVGBeak(CommonData calldata _commonData) external pure returns (bytes memory) {
        string[4][1] memory p = [
            ['M429.6 460l9.8 2.3a0.9 0.9 0 0 1 0.4 1.5l-7.3 6.8A0.9 0.9 0 0 1 431.1 470.3l-2.5-9.2A0.9 0.9 0 0 1 429.6 460Z', 'M447.8 420.9l13.1 3a1.2 1.2 0 0 1 0.6 2l-9.8 9.1A1.2 1.2 0 0 1 449.8 434.5l-3.3-12.2A1.2 1.2 0 0 1 447.8 420.9Z', 'M466.1 381.7l16.3 3.8a1.5 1.5 0 0 1 0.7 2.5l-12.2 11.4A1.5 1.5 0 0 1 468.5 398.8l-4.1-15.3A1.5 1.5 0 0 1 466.1 381.7Z', 'M484.3 342.5l19.6 4.5a1.8 1.8 0 0 1 0.8 3.1l-14.6 13.7A1.8 1.8 0 0 1 487.2 363l-5-18.2A1.8 1.8 0 0 1 484.3 342.5Z']
        ];

        return abi.encodePacked(
            '<path style="fill:#f69222" d="',
            p[0][uint256(_commonData.size)],
            '"/>'
        );
    }
}

contract ChickenOutChicken {
    function getSVGChicken(CommonData calldata _commonData, ChickenOutData calldata _chickenOutData) external pure returns (bytes memory) {
        string[4][3] memory p = [
            ['M417.8 446.5c-8.9-5.5-17-6.4-24.6-4.6-7.5 1.4-18.7 5.4-20.1 4.8-1.6-0.7 1.4 0.9 4.9 2-19.5 12.5-36.1 35.4-55.8 26.3-12.6-5.9-1.3 38 17.5 55.5s54.9 13.6 76.4-9.5S437.9 458.8 417.8 446.5Z', 'M432.1 402.8c-11.9-7.3-22.7-8.5-32.8-6.1-10 1.8-24.9 7.2-26.9 6.4-2.2-0.9 1.9 1.2 6.7 2.7-26 16.7-48.2 47.2-74.4 35-16.8-7.8-1.8 50.7 23.2 74s73.2 18.2 101.9-12.6S458.9 419.2 432.1 402.8Z', 'M446.4 359.2c-14.9-9.1-28.4-10.6-41-7.7-12.5 2.3-31.1 9.1-33.6 8-2.7-1.1 2.4 1.5 8.3 3.3-32.5 20.9-60.2 59-93 43.8-21-9.8-2.2 63.3 29 92.6s91.5 22.7 127.5-15.8S479.9 379.6 446.4 359.2Z', 'M460.7 315.5c-17.8-10.9-34.1-12.7-49.2-9.3-15 2.7-37.4 10.9-40.4 9.6-3.2-1.3 2.9 1.8 10 4.1-39 25.1-72.3 70.8-111.6 52.6-25.2-11.7-2.6 76 34.8 111s109.7 27.3 153-19S500.8 340 460.7 315.5Z'],
            ['M431.1 466.2a37 37 0 0 1-9.6 25.7c-21.2 24.2-52 30.3-81.5 38.9 18.8 17.2 54.7 13.2 76.1-9.8C430.5 505.6 435.4 483.1 431.1 466.2Z', 'M449.9 429.1a49.3 49.3 0 0 1-12.9 34.2c-28.2 32.3-69.4 40.4-108.7 51.9 25.1 22.9 72.9 17.6 101.5-13.1C449 481.6 455.5 451.7 449.9 429.1Z', 'M468.6 392a61.7 61.7 0 0 1-16.1 42.8c-35.3 40.3-86.7 50.5-135.8 64.8 31.4 28.6 91.1 22 126.9-16.3C467.5 457.7 475.7 420.2 468.6 392Z', 'M487.3 354.9a74 74 0 0 1-19.3 51.4c-42.4 48.4-104.1 60.5-163 77.7 37.7 34.3 109.3 26.4 152.3-19.5C486 433.7 495.8 388.8 487.3 354.9Z'],
            ['M417.8 446.5c-8.9-5.5-17-6.4-24.6-4.6-7.5 1.4-18.7 5.4-20.1 4.8-1.6-0.7 1.4 0.9 4.9 2-19.5 12.5-36.1 35.4-55.8 26.3-12.6-5.9-1.3 38 17.5 55.5s54.9 13.6 76.4-9.5S437.9 458.8 417.8 446.5Z', 'M432.1 402.8c-11.9-7.3-22.7-8.5-32.8-6.1-10 1.8-24.9 7.2-26.9 6.4-2.2-0.9 1.9 1.2 6.7 2.7-26 16.7-48.2 47.2-74.4 35-16.8-7.8-1.8 50.7 23.2 74s73.2 18.2 101.9-12.6S458.9 419.2 432.1 402.8Z', 'M446.4 359.2c-14.9-9.1-28.4-10.6-41-7.7-12.5 2.3-31.1 9.1-33.6 8-2.7-1.1 2.4 1.5 8.3 3.3-32.5 20.9-60.2 59-93 43.8-21-9.8-2.2 63.3 29 92.6s91.5 22.7 127.5-15.8S479.9 379.6 446.4 359.2Z', 'M460.7 315.5c-17.8-10.9-34.1-12.7-49.2-9.3-15 2.7-37.4 10.9-40.4 9.6-3.2-1.3 2.9 1.8 10 4.1-39 25.1-72.3 70.8-111.6 52.6-25.2-11.7-2.6 76 34.8 111s109.7 27.3 153-19S500.8 340 460.7 315.5Z']
        ];

        return abi.encodePacked(
            '<path style="',
            _chickenOutData.chickenStyle,
            '" d="',
            p[0][uint256(_commonData.size)],
            '"/><path style="fill:#000;mix-blend-mode:soft-light" d="',
            p[1][uint256(_commonData.size)],
            '"/><path style="fill:#000;mix-blend-mode:soft-light" d="',
            p[2][uint256(_commonData.size)],
            '"/>'
        );
    }
}

contract ChickenOutEye {
    function getSVGEye(CommonData calldata _commonData) external pure returns (bytes memory) {
        string[4][2] memory p = [
            ['cx="414.4" cy="457.6" r="5.5"', 'cx="427.5" cy="417.7" r="7.3"', 'cx="440.6" cy="377.7" r="9.2"', 'cx="453.7" cy="337.8" r="11"'],
            ['cx="414.4" cy="457.6" r="3.7"', 'cx="427.5" cy="417.7" r="5"', 'cx="440.6" cy="377.7" r="6.2"', 'cx="453.7" cy="337.8" r="7.4"']
        ];

        return abi.encodePacked(
            '<circle style="fill:#fff" ',
            p[0][uint256(_commonData.size)],
            '/><circle style="fill:#000" ',
            p[1][uint256(_commonData.size)],
            '/>'
        );
    }
}

contract ChickenOutShell {
    function getSVGShell(CommonData calldata _commonData, ChickenOutData calldata _chickenOutData) external pure returns (bytes memory) {
        string[4][2] memory p = [
            ['M409.2 512c-2.9-9.7-8.6-18.1-12.5-27.7-7.6 6.5-18.4 9.5-27.6 13.5-6.2-9.1-9.4-11.4-15.3-19.6-9.7 2.9-13.3 3.2-22.3 6.7-2.4-9.5-6.1-18.4-9.8-27.4a79.3 79.3 0 0 0-8.2 16.2c-11.6 32.6 5.2 68.3 37.5 79.7s67.8-5.7 79.4-38.3a81.6 81.6 0 0 0 3.7-16C426.5 504.6 417.8 507.9 409.2 512Z', 'M420.7 490.2c-3.8-13-11.5-24.1-16.7-37-10.2 8.7-24.5 12.7-36.8 18.1-8.3-12.2-12.5-15.2-20.5-26.2-13 3.8-17.7 4.3-29.7 9-3.2-12.7-8.1-24.5-13.1-36.6a105.8 105.8 0 0 0-10.9 21.6c-15.4 43.5 7 91 50 106.2s90.4-7.6 105.8-51a108.8 108.8 0 0 0 5-21.3C443.7 480.3 432.1 484.7 420.7 490.2Z', 'M432.1 468.4c-4.8-16.2-14.4-30.2-20.9-46.2-12.7 10.9-30.7 15.8-46 22.5-10.3-15.2-15.7-19-25.5-32.8-16.2 4.8-22.1 5.3-37.2 11.3-4-15.8-10.1-30.7-16.4-45.7a132.2 132.2 0 0 0-13.5 26.9c-19.3 54.3 8.7 113.8 62.4 132.9s113-9.5 132.3-63.8a136.1 136.1 0 0 0 6.2-26.6C460.9 456 446.4 461.6 432.1 468.4Z', 'M443.5 446.6c-5.7-19.5-17.3-36.2-25-55.5-15.3 13-36.8 19-55.2 27-12.4-18.3-18.8-22.8-30.7-39.3-19.5 5.7-26.6 6.4-44.6 13.6-4.8-19-12.1-36.8-19.7-54.9a158.7 158.7 0 0 0-16.2 32.3c-23.1 65.2 10.5 136.6 74.9 159.5s135.6-11.4 158.7-76.6a163.3 163.3 0 0 0 7.6-32C478 431.6 460.7 438.4 443.5 446.6Z'],
            ['M409.2 512c0-0.1-0.1-0.3-0.1-0.4-16.4 17.8-42.2 25.1-66.2 16.6a61.4 61.4 0 0 1-32.8-27.4 61.9 61.9 0 0 0 40.8 52.6c32.3 11.4 67.8-5.7 79.4-38.3a82 82 0 0 0 3.7-15.9C426.4 504.6 417.8 508 409.2 512Z', 'M420.7 490.2c-0.1-0.2-0.1-0.4-0.2-0.6-21.9 23.7-56.3 33.4-88.3 22.1a81.8 81.8 0 0 1-43.8-36.4 82.6 82.6 0 0 0 54.5 70c43 15.3 90.4-7.6 105.8-51a109.3 109.3 0 0 0 5-21.2C443.6 480.3 432.1 484.8 420.7 490.2Z', 'M432.1 468.4c-0.1-0.2-0.2-0.5-0.3-0.7-27.3 29.6-70.4 41.8-110.4 27.6a102.3 102.3 0 0 1-54.6-45.6 103.2 103.2 0 0 0 68.1 87.6c53.8 19.1 113-9.5 132.2-63.8a136.6 136.6 0 0 0 6.3-26.5C460.7 456 446.3 461.6 432.1 468.4Z', 'M443.5 446.6c-0.1-0.3-0.2-0.6-0.3-0.9-32.8 35.5-84.5 50.2-132.5 33.2a122.8 122.8 0 0 1-65.5-54.7 123.9 123.9 0 0 0 81.6 105c64.5 22.9 135.6-11.4 158.7-76.5a164 164 0 0 0 7.5-31.8C477.9 431.8 460.6 438.4 443.5 446.6Z']
        ];

        return abi.encodePacked(
            '<path style="',
            _chickenOutData.shellStyle,
            '" d="',
            p[0][uint256(_commonData.size)],
            '"/><path style="fill:#000;mix-blend-mode:soft-light" d="',
            p[1][uint256(_commonData.size)],
            '"/>'
        );
    }
}

contract ChickenOutGenerated1 is
  ChickenOutAnimations,
  ChickenOutShadow,
  ChickenOutLeftLeg,
  ChickenOutRightLeg,
  ChickenOutBeak,
  ChickenOutChicken,
  ChickenOutEye,
  ChickenOutShell
{}

contract ChickenOutGenerated {
    ChickenOutGenerated1 public immutable g1;

    constructor(ChickenOutGenerated1 _g1) {
        g1 = _g1;
    }

    function _getSVGAnimations(CommonData memory _commonData) internal view returns (bytes memory) {
        return g1.getSVGAnimations(_commonData);
    }

    function _getSVGShadow(CommonData memory _commonData) internal view returns (bytes memory) {
        return g1.getSVGShadow(_commonData);
    }

    function _getSVGLeftLeg(CommonData memory _commonData) internal view returns (bytes memory) {
        return g1.getSVGLeftLeg(_commonData);
    }

    function _getSVGRightLeg(CommonData memory _commonData) internal view returns (bytes memory) {
        return g1.getSVGRightLeg(_commonData);
    }

    function _getSVGBeak(CommonData memory _commonData) internal view returns (bytes memory) {
        return g1.getSVGBeak(_commonData);
    }

    function _getSVGChicken(CommonData memory _commonData, ChickenOutData memory _chickenOutData) internal view returns (bytes memory) {
        return g1.getSVGChicken(_commonData, _chickenOutData);
    }

    function _getSVGEye(CommonData memory _commonData) internal view returns (bytes memory) {
        return g1.getSVGEye(_commonData);
    }

    function _getSVGShell(CommonData memory _commonData, ChickenOutData memory _chickenOutData) internal view returns (bytes memory) {
        return g1.getSVGShell(_commonData, _chickenOutData);
    }
}
