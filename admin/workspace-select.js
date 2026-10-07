(function(root){
  'use strict';
  function createSelects(document){
    const controls=new Map();
    let opened=null;
    function close(){
      if(!opened)return;
      opened.menu.hidden=true;
      opened.trigger.setAttribute('aria-expanded','false');
      opened.trigger.removeAttribute('aria-activedescendant');
      opened=null;
    }
    function highlight(control,index){
      control.active=index;
      [...control.menu.children].forEach((option,i)=>option.classList.toggle('highlighted',i===index));
      control.trigger.setAttribute('aria-activedescendant',control.select.id+'-option-'+index);
    }
    function open(control){
      close();opened=control;
      control.menu.hidden=false;
      control.menu.classList.remove('opens-up');
      control.menu.style.left='0px';
      control.trigger.setAttribute('aria-expanded','true');
      const box=control.menu.getBoundingClientRect();
      if(box.bottom>document.defaultView.innerHeight-12&&control.trigger.getBoundingClientRect().top>box.height+12)control.menu.classList.add('opens-up');
      const rightLimit=document.defaultView.innerWidth-16;
      if(box.right>rightLimit)control.menu.style.left=(rightLimit-box.right)+'px';
      if(box.left<16)control.menu.style.left=(16-box.left)+'px';
      highlight(control,control.select.selectedIndex);
    }
    function sync(control){
      const {select,trigger,menu}=control;
      trigger.querySelector('span').textContent=select.selectedOptions[0]?.textContent||'';
      trigger.disabled=select.disabled;
      menu.replaceChildren(...[...select.options].map((option,index)=>{
        const button=document.createElement('button');
        button.type='button';button.role='option';button.tabIndex=-1;
        button.id=select.id+'-option-'+index;
        button.dataset.selectOption=String(index);
        button.setAttribute('aria-selected',String(index===select.selectedIndex));
        button.disabled=option.disabled;button.textContent=option.textContent;
        return button;
      }));
    }
    function enhance(){
      close();
      for(const id of ['workspace-type','workspace-state','workspace-page-size']){
        const select=document.getElementById(id);if(!select)continue;
        let control=controls.get(id);
        if(!control||control.select!==select){
          const label=select.closest('label');
          const textNodes=[...label.childNodes].filter(node=>node.nodeType===3);
          const name=textNodes.map(node=>node.textContent).join('').trim();
          const caption=document.createElement('span');caption.className='workspace-select-label';caption.textContent=name;
          textNodes.forEach(node=>node.remove());label.prepend(caption);
          const wrapper=document.createElement('span');wrapper.className='workspace-select-control';
          select.before(wrapper);wrapper.append(select);
          select.classList.add('workspace-select-native');select.tabIndex=-1;select.setAttribute('aria-hidden','true');
          const trigger=document.createElement('button');trigger.type='button';trigger.id=id+'-trigger';
          label.htmlFor=trigger.id;
          trigger.className='workspace-select-trigger';trigger.dataset.selectTrigger=id;
          trigger.role='combobox';trigger.setAttribute('aria-label',name);trigger.setAttribute('aria-haspopup','listbox');
          trigger.setAttribute('aria-expanded','false');trigger.setAttribute('aria-controls',id+'-options');
          trigger.innerHTML='<span></span><svg viewBox="0 0 16 16" aria-hidden="true" fill="none"><path d="m4 6 4 4 4-4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>';
          const menu=document.createElement('span');menu.id=id+'-options';menu.className='workspace-options';
          menu.role='listbox';menu.setAttribute('aria-label',name);menu.hidden=true;
          wrapper.append(trigger,menu);control={select,trigger,menu,active:0};controls.set(id,control);
        }
        sync(control);
      }
    }
    function choose(control,index){
      if(!control.select.options[index]||control.select.options[index].disabled)return;
      const id=control.select.id;control.select.selectedIndex=index;close();sync(control);
      control.select.dispatchEvent(new document.defaultView.Event('change',{bubbles:true}));
      document.getElementById(id+'-trigger')?.focus({preventScroll:true});
    }
    function click(event){
      const trigger=event.target.closest('[data-select-trigger]');
      if(trigger){event.preventDefault();const control=controls.get(trigger.dataset.selectTrigger);if(opened===control)close();else open(control);return;}
      const option=event.target.closest('[data-select-option]');
      if(option&&opened&&opened.menu.contains(option)){event.preventDefault();choose(opened,Number(option.dataset.selectOption));return;}
      close();
    }
    function keydown(event){
      const trigger=event.target.closest('[data-select-trigger]');if(!trigger)return;
      const control=controls.get(trigger.dataset.selectTrigger),last=control.select.options.length-1;
      if(event.key==='Tab'){close();return;}
      if(event.key==='Escape'){event.preventDefault();close();return;}
      if(['Enter',' '].includes(event.key)){event.preventDefault();if(opened===control)choose(control,control.active);else open(control);return;}
      if(['ArrowDown','ArrowUp','Home','End'].includes(event.key)){
        event.preventDefault();const wasOpen=opened===control;if(!wasOpen)open(control);
        const index=event.key==='Home'?0:event.key==='End'?last:wasOpen?Math.max(0,Math.min(last,control.active+(event.key==='ArrowDown'?1:-1))):control.active;
        highlight(control,index);
      }else if(event.key.length===1&&!event.ctrlKey&&!event.metaKey&&!event.altKey){
        const index=[...control.select.options].findIndex(option=>option.textContent.toLocaleLowerCase().startsWith(event.key.toLocaleLowerCase()));
        if(index>=0){event.preventDefault();if(opened!==control)open(control);highlight(control,index);}
      }
    }
    function focusout(event){if(opened&&!opened.trigger.parentElement.contains(event.relatedTarget))close();}
    document.addEventListener('click',click);document.addEventListener('keydown',keydown);document.addEventListener('focusout',focusout);
    document.defaultView.addEventListener('resize',close);
    return {enhance,close,destroy(){close();document.removeEventListener('click',click);document.removeEventListener('keydown',keydown);document.removeEventListener('focusout',focusout);document.defaultView.removeEventListener('resize',close);controls.clear();}};
  }
  root.HourTVWorkspaceSelect={createSelects};
})(typeof globalThis!=='undefined'?globalThis:this);
