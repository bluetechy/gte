package lse.math.games.builder.view 
{		
	import flash.display.DisplayObject;
	import flash.text.engine.TextLine;
	
	import lse.math.games.builder.model.Rational;
	import lse.math.games.builder.presenter.IAction;
	import lse.math.games.builder.presenter.TreeGridPresenter;
	import lse.math.games.builder.viewmodel.TreeGrid;
	import lse.math.games.builder.viewmodel.action.LabelChangeAction;
	import lse.math.games.builder.viewmodel.action.PayChangeAction;
	
	import mx.controls.Alert;
	
	import util.Log;
	import util.PromptTextInput;
	
	/**
	 * Linked list of Painters, usable as Painter itself, applying each operation to the whole list
	 * It also contains functionality for selecting and editing labels
	 * @author Mark
	 */
	public class PainterChain implements IPainter
	{
		private var _start:PainterChainLink;
		private var _end:PainterChainLink;
		
		private var log:Log = Log.instance;
		
		
		
		public function PainterChain() {}
		
		public function set links(value:Vector.<IPainter>):void {
			for each (var painter:IPainter in value) 
			{
				var link:PainterChainLink = new PainterChainLink(painter);			
				if (_start == null) {
					_start = link;
				}
				if (_end != null) {
					_end.next = link;
				}
				_end = link;
			}
		}
		
		/** Runs all the painters' paint function, therefore painting everything under its control */
		public function paint(g:IGraphics, width:Number, height:Number):void 
		{			
			for (var link:PainterChainLink = _start; link != null; link = link.next) {
				link.painter.paint(g, width, height);
			}			
		}
		
		/** Assigns all labels corresponding to all the painters. They get registered under each painter's own labels array */
		public function assignLabels():void 
		{
			for (var link:PainterChainLink = _start; link != null; link = link.next) {
				link.painter.assignLabels();
			}				
		}
		
		/** Performs all the necessary measurements to perform correctly the painting operations */
		public function measureCanvas():void 
		{
			for (var link:PainterChainLink = _start; link != null; link = link.next) {
				link.painter.measureCanvas();
			}				
		}
		
		/** Collects and returns an object containing all the labels inside the painters */
		public function get labels():Object {
			var labels:Object = new Object();
			for (var link:PainterChainLink = _start; link != null; link = link.next) {				
				for (var labelKey:String in link.painter.labels) {
					labels[labelKey] = link.painter.labels[labelKey];
				}
			}
			return labels;
		}
		
		/** Returns the maximum of the drawWidths of the painters*/
		public function get drawWidth():Number {
			var maxWidth:Number = 0;
			for (var link:PainterChainLink = _start; link != null; link = link.next) {
				if (link.painter.drawWidth > maxWidth) {
					maxWidth = link.painter.drawWidth;
				}
			}
			return maxWidth;
		}
		
		/** Returns the maximum of the drawHeights of the painters*/
		public function get drawHeight():Number {
			var maxHeight:Number = 0;
			for (var link:PainterChainLink = _start; link != null; link = link.next) {
				if (link.painter.drawHeight > maxHeight) {
					maxHeight = link.painter.drawHeight;
				}
			}
			return maxHeight;			
		}
		
		[Bindable]
		public function get scale():Number {
			return _start != null ? _start.painter.scale : 1.0;			
		}
		
		public function set scale(value:Number):void {			
			for (var link:PainterChainLink = _start; link != null; link = link.next) {				
				link.painter.scale = value;
			}		
		}
		
		private var _selectedLabelKey:String;
		private var _controller:TreeGridPresenter;
		
		/** Launches a prompt to edit a selected label. In future versions its functionality might be widened to nodes and other things */
		public function selectAndEdit(controller:TreeGridPresenter, x:Number, y:Number):void
		{
			_controller = controller;
			_selectedLabelKey = null;
			for (var labelKey:String in labels)
			{
				var label:TextLine = labels[labelKey];
				if(label.x<=x && label.x+label.width>=x &&
					label.y>=y && label.y-label.height<=y)
				{
					if(labelKey.indexOf("iset_")==0)
					{
						log.add(Log.HINT, "Iset editing is not supported yet");
					} else if(labelKey.indexOf("move_")==0)
					{						
						PromptTextInput.show(onReturnFromPrompt, label.textBlock.content.rawText, "Introduce new name for the move");
						_selectedLabelKey = labelKey;
						break;
					}
					else if(labelKey.indexOf("outcome_")==0)
					{
						PromptTextInput.show(onReturnFromPrompt, label.textBlock.content.rawText, "Introduce new value for the payoff");
						_selectedLabelKey = labelKey;
						break;
					}
				}
			}
		}
		
		//Executes the edit action
		private function onReturnFromPrompt():void
		{
			if(PromptTextInput.lastEnteredText!=null && PromptTextInput.lastEnteredText!="")
			{
				_controller.doAction(getEditAction);
			}
		}
		
		//Builds a 'edit action' which can be a LabelChangeAction or a PayChangeAction, depending on what was edited
		private function getEditAction(grid:TreeGrid):IAction
		{
			var action:IAction = null;
			
			if(_selectedLabelKey.indexOf("move_")==0)
			{
				var id:int = parseInt(_selectedLabelKey.split("_")[1]);
				action = new LabelChangeAction(id, PromptTextInput.lastEnteredText);
			} else if(_selectedLabelKey.indexOf("outcome_")==0)
			{
				var payCode:String = (_selectedLabelKey.split("_")[1]);
				id = parseInt(payCode.split(":")[0]);
				var playerName:String = payCode.split(":")[1];
					
				var pay:Rational = Rational.parse(PromptTextInput.lastEnteredText);
				if(pay==Rational.NaN)
				{
					log.add(Log.ERROR, "Bad number format, please use just numbers and '/' '.' characters for decimals");
					return null;
				}
				if(grid.isZeroSum)
				{
					if(playerName == grid.firstPlayer.name)
						action = new PayChangeAction(id, pay, pay.negate());
					else if(playerName == grid.firstPlayer.nextPlayer.name)
						action = new PayChangeAction(id, pay.negate(), pay);
				}else
				{
					if(playerName == grid.firstPlayer.name)
						action = new PayChangeAction(id, pay, null);
					else if(playerName == grid.firstPlayer.nextPlayer.name)
						action = new PayChangeAction(id, null, pay);
				}
			}else
				log.add(Log.ERROR_THROW, "ERROR: Unknown type of Label being modified");
			
			return action;
		}
	}
}

import lse.math.games.builder.view.IPainter;
class PainterChainLink
{
	private var _painter:IPainter;
	public var next:PainterChainLink;	
	
	public function PainterChainLink(painter:IPainter)
	{
		_painter = painter;
	}
	
	public function get painter():IPainter {
		return _painter;
	}
}