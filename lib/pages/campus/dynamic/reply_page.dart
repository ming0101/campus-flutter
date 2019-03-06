import 'package:campus/common/dao/dynamic_dao.dart';
import 'package:campus/common/model/comment.dart';
import 'package:campus/common/model/message.dart';
import 'package:campus/common/model/reply.dart';
import 'package:campus/common/style/colors.dart';
import 'package:campus/common/style/context_style.dart';
import 'package:campus/common/style/string_tip.dart';
import 'package:campus/common/utils/common_utils.dart';
import 'package:campus/common/utils/taost_utils.dart';
import 'package:campus/widget/item/reply_item_widget.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyrefresh/easy_refresh.dart';

class ReplyPage extends StatefulWidget {
  final CommentData data;

  ReplyPage(this.data);

  @override
  State<StatefulWidget> createState() => _ReplyPage();
}

class _ReplyPage extends State<ReplyPage> {
  List<ReplyData> list = <ReplyData>[];

  final TextEditingController _replyController = TextEditingController();
  GlobalKey<EasyRefreshState> _easyRefreshKey =
      new GlobalKey<EasyRefreshState>();
  GlobalKey<RefreshHeaderState> _headerKey =
      new GlobalKey<RefreshHeaderState>();
  GlobalKey<RefreshFooterState> _footerKey =
      new GlobalKey<RefreshFooterState>();

  bool _isLoadMore = false;
  String _replyName;
  String _replyID;
  bool _isShowInputView = false;
  bool _isReplyPublish = false;

  CancelToken dioToken = new CancelToken();
  @override
  void initState() {
    _replyName = widget.data.name;
    _replyID = widget.data.id;
    getReplyList();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.data.replyCount} 条回复"),
        centerTitle: true,
      ),
      body: Column(
        children: <Widget>[
          Flexible(
              child: EasyRefresh(
            key: _easyRefreshKey,
            onRefresh: () {
              getReplyList();
            },
            loadMore: () {
              if (_isLoadMore) {
                getMoreReplyList(list.last.id);
              }else{
                ToastUtils.showShortInfoToast(StringTip.load_more_none);
              }
            },
            refreshHeader: ClassicsHeader(
              key: _headerKey,
              refreshText: "刷新动态",
              refreshReadyText: "释放刷新",
              refreshingText: "获取动态...",
              refreshedText: "刷新完成",
              moreInfo: "上次于 ${DateTime.now().toString().substring(11, 16)} 更新",
              bgColor: Colors.transparent,
              textColor: Colors.black87,
              moreInfoColor: Colors.black54,
              showMore: true,
            ),
            refreshFooter: ClassicsFooter(
              key: _footerKey,
              loadText: "加载更多",
              loadReadyText: "释放获取数据",
              loadingText: "加载更多动态...",
              noMoreText: "加载完成",
              bgColor: Colors.transparent,
              textColor: Colors.black87,
              moreInfoColor: Colors.black54,
            ),
            child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, position) {
                  return ReplyItemWidget(
                    list[position],
                    onTapReply: () {
                      setState(() {
                        _replyName = list[position].name;
                        _replyID = list[position].id;
                        _isShowInputView = !_isShowInputView;
                        _replyController.clear();
                      });
                    },
                  );
                }),
          )),
          Divider(
            height: 1.0,
          ),
          buildBottomWidget()
        ],
      ),
    );
  }

  Widget buildBottomWidget() {
    if (_isShowInputView) {
      return Container(
        width: double.infinity,
        child: Column(
          children: <Widget>[
            TextField(
              maxLines: null,
              controller: _replyController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.only(
                    left: 15.0, top: 8.0, right: 15.0, bottom: 8.0),
                labelText: "回复: $_replyName",
                hintText: StringTip.comment_tip,
                border: InputBorder.none,
              ),
              style: ContextStyle.inputContent,
              keyboardType: TextInputType.text,
              autofocus: true,
              onChanged: (String value) {
                if (value.trim().length > 0) {
                  setState(() {
                    _isReplyPublish = true;
                  });
                }
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                FlatButton(
                  onPressed: () {
                    setState(() {
                      _isShowInputView = !_isShowInputView;
                      _isReplyPublish = false;
                    });
                  },
                  child: Text("取消"),
                ),
                OutlineButton(
                  onPressed: _isReplyPublish
                      ? () {
                          if (_replyController.text.length > 500) {
                            ToastUtils.showShortErrorToast(
                                StringTip.length_oversize_tip);
                          } else {
                            if(CommonUtils.getGlobalStore(context).state.token.isLogin){
                              sendReply(_replyController.text);
                            }else{
                              ToastUtils.showShortWarnToast(StringTip.after_login);
                            }
                          }
                        }
                      : null,
                  borderSide: GlobalColors.greenBorderSide,
                  color: Colors.lightBlueAccent,
                  child: Text("回复"),
                )
              ],
            )
          ],
        ),
      );
    } else {
      return FlatButton(
        onPressed: () {
          setState(() {
            _replyName = widget.data.name;
            _replyID = widget.data.id;
            _isShowInputView = !_isShowInputView;
          });
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text("回复: ${widget.data.name}"),
        ),
      );
    }
  }

  sendReply(String content) async {
    Message result = await DynamicDao.sendDynamicCommentReply(context, content, _replyID,cancelToken: dioToken);
    if (result.ok) {
      _replyController.clear();
      setState(() {
        _isShowInputView = !_isShowInputView;
        _isReplyPublish = false;
        ++widget.data.replyCount;
      });
      getReplyList();
      ToastUtils.showShortSuccessToast(result.msg);
    } else {
      ToastUtils.showShortErrorToast(result.msg);
    }
  }

  getReplyList() async {
    Reply result = await DynamicDao.getDynamicReplyList(widget.data.id,cancelToken: dioToken);
    if (result.ok) {
      if (result.data.length == 10) {
        _isLoadMore = true;
      }
      setState(() {
        list.clear();
        list.addAll(result.data);
      });
    } else {
      ToastUtils.showShortErrorToast(result.msg);
    }
  }

  getMoreReplyList(String lastID) async {
    Reply result =
        await DynamicDao.getDynamicReplyList(widget.data.id, lastID: lastID,cancelToken: dioToken);
    if (result.ok) {
      if (result.data.length < 10) {
        _isLoadMore = false;
      }
      setState(() {
        list.addAll(result.data);
      });
    } else {
      ToastUtils.showShortErrorToast(result.msg);
    }
  }

  @override
  void dispose() {
    dioToken.cancel();
    super.dispose();
  }
}
